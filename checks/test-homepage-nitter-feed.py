#!/usr/bin/env python3
"""Check Nitter RSS parsing, fallback scheduling and the Homepage JSON API."""

import importlib.util
import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/homepage-nitter-feed.py"
spec = importlib.util.spec_from_file_location("homepage_nitter_feed", SCRIPT)
assert spec is not None and spec.loader is not None
feed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(feed)

RSS = """<?xml version="1.0"?>
<rss version="2.0"><channel>
  <title>Tibo / @thsottiaux</title>
  <link>http://nitter.meowing.monster/thsottiaux</link>
  <description>Twitter feed for @thsottiaux.</description>
  <item><title>Day 26: resets and banked</title>
    <description><![CDATA[<p>Day 26/ Next two days will be resets… banked…<br>
      <a href="https://help.openai.com/">help.openai.com/…</a></p><hr/>
      <blockquote>Quoted text must not appear.</blockquote>]]></description>
    <pubDate>Sat, 31 Oct 2026 05:42:26 GMT</pubDate>
    <link>http://nitter.meowing.monster/thsottiaux/status/2116405414921384099#m</link>
  </item>
  <item><title>Banked 1/2</title>
    <description><![CDATA[<p>Banked 1/2</p>]]></description>
    <pubDate>Sun, 01 Nov 2026 00:43:20 GMT</pubDate>
    <link>http://nitter.meowing.monster/thsottiaux/status/2116692529970311254#m</link>
  </item>
  <item><title>Older post</title><description><![CDATA[<p>Old RESET</p>]]></description>
    <pubDate>Thu, 29 Oct 2026 16:56:07 GMT</pubDate>
    <link>http://nitter.meowing.monster/thsottiaux/status/2115850175868727621#m</link>
  </item>
  <item><title>Later than previous in feed order</title><description><![CDATA[<p>Later BANKED</p>]]></description>
    <pubDate>Thu, 29 Oct 2026 17:01:51 GMT</pubDate>
    <link>http://nitter.meowing.monster/thsottiaux/status/2115851621137784832#m</link>
  </item>
  <item><title>Fifth</title><description><![CDATA[<p>Fifth RESET</p>]]></description>
    <pubDate>Wed, 28 Oct 2026 15:58:02 GMT</pubDate>
    <link>http://nitter.meowing.monster/thsottiaux/status/2115473170279080149#m</link>
  </item>
  <item><title>Sixth</title><description><![CDATA[<p>Sixth banked</p>]]></description>
    <pubDate>Wed, 28 Oct 2026 06:29:38 GMT</pubDate>
    <link>http://nitter.meowing.monster/thsottiaux/status/2115330127886463244#m</link>
  </item>
  <item><title>Newest unrelated</title>
    <description><![CDATA[<p>Unrelated update</p>]]></description>
    <pubDate>Mon, 02 Nov 2026 00:00:00 GMT</pubDate>
    <link>http://nitter.meowing.monster/thsottiaux/status/2117000000000000000#m</link>
  </item>
</channel></rss>""".encode()


class NitterFeedTests(unittest.TestCase):
    def test_rss_filters_banked_or_reset_before_selecting_latest_five(self) -> None:
        posts = feed.parse_feed(RSS)
        self.assertEqual(len(posts), 5)
        self.assertEqual(
            [post["id"] for post in posts],
            [
                "2116692529970311254",
                "2116405414921384099",
                "2115851621137784832",
                "2115850175868727621",
                "2115473170279080149",
            ],
        )
        self.assertEqual(posts[0]["text"], "Banked 1/2")
        self.assertEqual(posts[0]["id"], "2116692529970311254")
        self.assertEqual(
            posts[0]["url"],
            "https://nitter.meowing.monster/thsottiaux/status/2116692529970311254#m",
        )
        self.assertEqual(
            posts[1]["text"],
            "Day 26/ Next two days will be resets… banked… help.openai.com/…",
        )
        self.assertNotIn("Quoted text", json.dumps(posts))
        self.assertEqual(posts[2]["text"], "Later BANKED")
        self.assertEqual(posts[3]["text"], "Old RESET")
        self.assertEqual(posts[-1]["text"], "Fifth RESET")
        self.assertNotIn("Unrelated update", json.dumps(posts))

    def test_wrong_account_and_unsafe_post_links_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            feed.parse_feed(RSS.replace(b"@thsottiaux", b"@someone-else", 1))
        with self.assertRaises(ValueError):
            feed.post_url("https://evil.example/thsottiaux/status/123#m")
        with self.assertRaises(ValueError):
            feed.parse_feed(
                RSS.replace(b"<rss", b"<!DOCTYPE rss [<!ENTITY x 'x'>]><rss", 1)
            )

    def test_backoff_preserves_last_good_cache_and_success_resets_it(self) -> None:
        posts = feed.parse_feed(RSS)
        with tempfile.TemporaryDirectory() as temporary:
            cache = feed.FeedCache(Path(temporary) / "feed.json")
            self.assertTrue(cache.refresh(lambda: posts, now=1000))
            self.assertEqual(cache.snapshot()["nextAttemptAt"], 1900)
            self.assertFalse(
                cache.refresh(lambda: (_ for _ in ()).throw(OSError()), now=1900)
            )
            self.assertEqual(cache.snapshot()["items"], posts)
            self.assertEqual(cache.snapshot()["failures"], 1)
            self.assertEqual(cache.snapshot()["nextAttemptAt"], 2800)
            self.assertEqual(cache.public(now=1900)["status"], "stale")
            self.assertFalse(
                cache.refresh(lambda: (_ for _ in ()).throw(OSError()), now=2800)
            )
            self.assertEqual(cache.snapshot()["failures"], 2)
            self.assertEqual(cache.snapshot()["nextAttemptAt"], 4600)
            self.assertTrue(cache.refresh(lambda: posts, now=4600))
            self.assertEqual(cache.snapshot()["failures"], 0)
            self.assertEqual(cache.snapshot()["nextAttemptAt"], 5500)
            self.assertEqual(feed.FeedCache(cache.path).snapshot()["items"], posts)
            self.assertEqual(feed.retry_delay(20), feed.MAX_BACKOFF_SECONDS)

    def test_http_429_retry_after_delta_and_http_date(self) -> None:
        cases = (
            ("3600", 1000, 4600),
            ("Thu, 01 Jan 1970 03:00:00 GMT", 2000, 10800),
        )
        for retry_after, now, expected in cases:
            with (
                self.subTest(retry_after=retry_after),
                tempfile.TemporaryDirectory() as temporary,
            ):
                cache = feed.FeedCache(Path(temporary) / "feed.json")
                error = urllib.error.HTTPError(
                    feed.FEED_URL,
                    429,
                    "Too Many Requests",
                    {"Retry-After": retry_after},
                    None,
                )
                self.assertFalse(cache.refresh(mock.Mock(side_effect=error), now=now))
                self.assertEqual(cache.snapshot()["nextAttemptAt"], expected)

    def test_failed_refresh_marks_fallback_stale(self) -> None:
        posts = feed.parse_feed(RSS)
        with tempfile.TemporaryDirectory() as temporary:
            cache = feed.FeedCache(Path(temporary) / "feed.json")
            self.assertTrue(cache.refresh(lambda: posts, now=1000))
            self.assertEqual(cache.public(now=1100)["status"], "ok")
            self.assertFalse(
                cache.refresh(mock.Mock(side_effect=OSError("unavailable")), now=1100)
            )
            self.assertEqual(cache.snapshot()["items"], posts)
            self.assertEqual(cache.public(now=1100)["status"], "stale")

    def test_json_api_serves_cached_posts_and_only_its_endpoint(self) -> None:
        posts = feed.parse_feed(RSS)
        with tempfile.TemporaryDirectory() as temporary:
            cache = feed.FeedCache(Path(temporary) / "feed.json")
            cache.refresh(lambda: posts, now=1_800_000_000)
            server = feed.ThreadingHTTPServer(
                ("127.0.0.1", 0), feed.make_handler(cache)
            )
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                address = f"http://127.0.0.1:{server.server_port}"
                with urllib.request.urlopen(  # noqa: S310 -- Disposable loopback fixture.
                    address + "/posts.json", timeout=3
                ) as response:
                    value = json.load(response)
                    self.assertEqual(
                        response.headers["Content-Type"],
                        "application/json; charset=utf-8",
                    )
                    self.assertEqual(value["status"], "ok")
                    self.assertEqual(len(value["items"]), 5)
                    self.assertIn("#m", value["items"][0]["url"])
                    self.assertNotIn("<p>", json.dumps(value))
                with self.assertRaises(urllib.error.HTTPError):
                    urllib.request.urlopen(address + "/feed.json", timeout=3)  # noqa: S310 -- Disposable loopback fixture.
            finally:
                server.shutdown()
                server.server_close()
                thread.join()


if __name__ == "__main__":
    unittest.main()
