#!/usr/bin/env python3
"""Cache one public Nitter RSS feed and serve a small Homepage JSON API."""

from __future__ import annotations

import email.utils
import html.parser
import http.client
import json
import math
import os
import re
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from collections.abc import Callable
from datetime import UTC, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

FEED_URL = "https://nitter.meowing.monster/thsottiaux/rss"
INSTANCE_HOST = "nitter.meowing.monster"
HANDLE = "thsottiaux"
REFRESH_SECONDS = 15 * 60
MAX_BACKOFF_SECONDS = 6 * 60 * 60
FETCH_TIMEOUT_SECONDS = 15
MAX_FEED_BYTES = 1_000_000
MAX_TEXT_LENGTH = 500
PORT = 3002


class DescriptionText(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.ignored = 0
        self.stopped = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        del attrs
        if tag in {"hr", "blockquote"}:
            self.stopped = True
        elif tag in {"script", "style"}:
            self.ignored += 1
        elif tag in {"br", "p", "div"}:
            self.parts.append(" ")

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style"} and self.ignored:
            self.ignored -= 1
        elif tag in {"p", "div"}:
            self.parts.append(" ")

    def handle_data(self, data: str) -> None:
        if not self.stopped and not self.ignored:
            self.parts.append(data)


def plain_text(value: str) -> str:
    parser = DescriptionText()
    parser.feed(value)
    text = " ".join(" ".join(parser.parts).split())
    if len(text) > MAX_TEXT_LENGTH:
        return text[: MAX_TEXT_LENGTH - 1].rstrip() + "…"
    return text


def post_url(value: str) -> str:
    parsed = urlsplit(value.strip())
    match = re.fullmatch(rf"/{HANDLE}/status/(\d+)", parsed.path)
    if (
        parsed.scheme not in {"http", "https"}
        or parsed.netloc.lower() != INSTANCE_HOST
        or parsed.query
        or not match
    ):
        raise ValueError("Invalid post link in feed")
    return urlunsplit(("https", INSTANCE_HOST, parsed.path, "", "m"))


def parse_feed(payload: bytes) -> list[dict[str, str]]:
    if re.search(rb"<!DOCTYPE|<!ENTITY", payload, re.IGNORECASE):
        raise ValueError("RSS feed must not contain a DTD or entity declaration")
    root = ET.fromstring(payload)  # noqa: S314 -- DTD/entities are rejected and input is size-limited.
    if root.tag != "rss":
        raise ValueError("Feed is not RSS")
    channel = root.find("channel")
    if channel is None:
        raise ValueError("RSS channel is missing")
    title = channel.findtext("title", "")
    profile = urlsplit(channel.findtext("link", ""))
    if (
        f"@{HANDLE}" not in title
        or profile.netloc.lower() != INSTANCE_HOST
        or profile.path.rstrip("/") != f"/{HANDLE}"
    ):
        raise ValueError("RSS feed is not for the configured account")

    posts = []
    for item in channel.findall("item"):
        description = item.findtext("description", "")
        text = plain_text(description) or plain_text(item.findtext("title", ""))
        pub_date = email.utils.parsedate_to_datetime(item.findtext("pubDate", ""))
        if pub_date.tzinfo is None:
            pub_date = pub_date.replace(tzinfo=UTC)
        published = pub_date.astimezone(UTC).isoformat().replace("+00:00", "Z")
        if text:
            posts.append(
                {
                    "id": urlsplit(item.findtext("link", "")).path.rsplit("/", 1)[-1],
                    "text": text,
                    "published": published,
                    "url": post_url(item.findtext("link", "")),
                }
            )
    if channel.findall("item") and not posts:
        raise ValueError("RSS feed has no valid posts")
    posts = [
        post
        for post in posts
        if any(keyword in post["text"].casefold() for keyword in ("banked", "reset"))
    ]
    return sorted(posts, key=lambda post: post["published"], reverse=True)[:5]


def fetch_feed() -> list[dict[str, str]]:
    request = urllib.request.Request(
        FEED_URL,
        headers={
            "Accept": "application/rss+xml, application/xml;q=0.9",
            "User-Agent": "PowerLAN-Homepage-Nitter-Feed/1.0",
        },
    )
    with urllib.request.urlopen(  # noqa: S310 -- Fixed public RSS URL; final host is checked below.
        request, timeout=FETCH_TIMEOUT_SECONDS
    ) as response:
        final_url = urlsplit(response.geturl())
        if final_url.scheme != "https" or final_url.netloc.lower() != INSTANCE_HOST:
            raise ValueError("Feed redirected outside the configured Nitter instance")
        payload = response.read(MAX_FEED_BYTES + 1)
    if len(payload) > MAX_FEED_BYTES:
        raise ValueError("RSS feed exceeds the size limit")
    return parse_feed(payload)


def iso_time(timestamp: float) -> str:
    return datetime.fromtimestamp(timestamp, UTC).isoformat().replace("+00:00", "Z")


def empty_state() -> dict[str, object]:
    return {
        "items": [],
        "fetchedAt": None,
        "lastAttemptAt": None,
        "failures": 0,
        "nextAttemptAt": 0,
    }


def retry_delay(failures: int) -> int:
    exponent = min(max(failures - 1, 0), 5)
    return min(REFRESH_SECONDS * (2**exponent), MAX_BACKOFF_SECONDS)


def retry_after_seconds(error: Exception, now: float) -> int | None:
    if not isinstance(error, urllib.error.HTTPError) or error.code != 429:
        return None
    value = error.headers.get("Retry-After") if error.headers is not None else None
    if value is None:
        return None
    value = value.strip()
    if value.isascii() and value.isdecimal():
        return int(value)
    try:
        retry_at = email.utils.parsedate_to_datetime(value)
        if retry_at.tzinfo is None:
            retry_at = retry_at.replace(tzinfo=UTC)
        return max(0, math.ceil(retry_at.timestamp() - now))
    except (OverflowError, TypeError, ValueError):
        return None


class FeedCache:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.lock = threading.Lock()
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(value, dict) or not isinstance(value.get("items"), list):
                raise TypeError("Invalid feed cache")
            self.state = value
        except (OSError, TypeError, ValueError):
            self.state = empty_state()

    def snapshot(self) -> dict[str, object]:
        with self.lock:
            return self.state | {"items": list(self.state["items"])}

    def save(self) -> None:
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                dir=self.path.parent,
                prefix=".feed-",
                delete=False,
            ) as output:
                temporary = Path(output.name)
                os.fchmod(output.fileno(), 0o600)
                json.dump(self.state, output, ensure_ascii=False)
                output.flush()
                os.fsync(output.fileno())
            temporary.replace(self.path)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)

    def refresh(
        self,
        fetch: Callable[[], list[dict[str, str]]] = fetch_feed,
        now: float | None = None,
    ) -> bool:
        now = time.time() if now is None else now
        try:
            items = fetch()
        except (
            OSError,
            ValueError,
            TypeError,
            ET.ParseError,
            http.client.HTTPException,
            urllib.error.URLError,
        ) as error:
            with self.lock:
                failures = int(self.state.get("failures", 0)) + 1
                delay = retry_after_seconds(error, now)
                if delay is None:
                    delay = retry_delay(failures)
                self.state = self.state | {
                    "lastAttemptAt": iso_time(now),
                    "failures": failures,
                    "nextAttemptAt": now + delay,
                }
                try:
                    self.save()
                except OSError:
                    print(
                        "Could not persist the Nitter feed fallback cache",
                        file=sys.stderr,
                    )
            print(
                f"Nitter feed refresh failed ({type(error).__name__}); retry in {delay}s",
                file=sys.stderr,
                flush=True,
            )
            return False

        with self.lock:
            self.state = {
                "items": items[:5],
                "fetchedAt": iso_time(now),
                "lastAttemptAt": iso_time(now),
                "failures": 0,
                "nextAttemptAt": now + REFRESH_SECONDS,
            }
            try:
                self.save()
            except OSError:
                print("Could not persist the Nitter feed cache", file=sys.stderr)
        return True

    def public(self, now: float | None = None) -> dict[str, object]:
        state = self.snapshot()
        fetched_at = state.get("fetchedAt")
        try:
            fetched_time = datetime.fromisoformat(str(fetched_at))
            stale = (
                int(state.get("failures", 0)) > 0
                or (time.time() if now is None else now) - fetched_time.timestamp()
                > REFRESH_SECONDS
            )
        except (TypeError, ValueError):
            stale = True
        return {
            "items": state["items"],
            "updatedAt": fetched_at,
            "status": "stale" if stale else "ok",
        }


def make_handler(cache: FeedCache) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if urlsplit(self.path).path != "/posts.json":
                self.send_error(404)
                return
            body = json.dumps(cache.public(), ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, message_format: str, *args: object) -> None:
            del message_format, args

    return Handler


def refresh_loop(cache: FeedCache, stop: threading.Event) -> None:
    while not stop.is_set():
        next_attempt = float(cache.snapshot().get("nextAttemptAt", 0))
        delay = next_attempt - time.time()
        if delay > 0:
            stop.wait(min(delay, 60))
        else:
            cache.refresh()


def main() -> None:
    state_directory = Path(
        os.environ.get("STATE_DIRECTORY", "/var/lib/homepage-nitter-feed")
    )
    cache = FeedCache(state_directory / "feed.json")
    stop = threading.Event()
    threading.Thread(target=refresh_loop, args=(cache, stop), daemon=True).start()
    server = ThreadingHTTPServer(("127.0.0.1", PORT), make_handler(cache))
    try:
        server.serve_forever()
    finally:
        stop.set()
        server.server_close()


if __name__ == "__main__":
    main()
