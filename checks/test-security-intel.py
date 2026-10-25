"""Offline API, cache, inventory and no-build checks for security intelligence."""

import importlib.util
import io
import json
import sys
import tempfile
import unittest
import urllib.error
import urllib.parse
from collections.abc import Callable
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "security_intel", ROOT / "scripts/security-intel.py"
)
API = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(API)
CVE = "CVE-2026-12345"


def suggestion(identifier: str = CVE, package: str = "uv") -> dict:
    return {
        "cve_id": identifier,
        "status": "published",
        "packages": {package: {"branches": {}}},
    }


def entry(identifier: str = "EUVD-2026-12345", package: str = "uv") -> dict:
    return {
        "id": identifier,
        "aliases": CVE + "\nGHSA-aaaa-bbbb-cccc\n",
        "baseScore": 9.1,
        "epss": 0.7,
        "enisaIdProduct": [{"product": {"name": package}, "product_version": "<0.10"}],
    }


class FakeClient:
    def __init__(self, handler: Callable[[str], dict] | None = None) -> None:
        self.requests = []
        self.handler = handler or self.response

    def get(self, url: str) -> dict:
        self.requests.append({"url": url})
        return self.handler(url)

    @staticmethod
    def response(url: str) -> dict:
        if url.startswith(API.TRACKER):
            return {"count": 1, "next": None, "results": [suggestion()]}
        return {"total": 1, "items": [entry()]}


class Response(io.BytesIO):
    def geturl(self) -> str:
        return API.EUVD


class SecurityIntelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.component = {
            "name": "uv",
            "version": "0.13.5",
            "reference": "pkg:nix/uv@0.13.5",
        }

    def test_root_and_nested_inventory(self) -> None:
        document = {
            "bomFormat": "CycloneDX",
            "metadata": {"component": {"name": "root", "version": "1"}},
            "components": [
                {
                    "name": "uv",
                    "version": "0.13.5",
                    "components": [{"name": "child", "version": "2"}],
                }
            ],
        }
        self.assertEqual(
            {item["name"] for item in API.inventory(document)}, {"root", "uv", "child"}
        )
        self.assertIsNone(
            API.inventory(
                {"bomFormat": "CycloneDX", "components": [{"name": "unversioned"}]}
            )[0]["version"]
        )
        for value in [
            {},
            {"bomFormat": "CycloneDX", "components": []},
            {"bomFormat": "CycloneDX", "components": [{"name": "uv", "version": []}]},
        ]:
            with self.subTest(value=value), self.assertRaises((TypeError, ValueError)):
                API.inventory(value)

    def test_deduplicates_sources_without_assuming_local_version_is_affected(
        self,
    ) -> None:
        report = API.assess([self.component], FakeClient())
        self.assertEqual(report["status"], "complete")
        self.assertEqual(len(report["advisories"]), 1)
        advisory = report["advisories"][0]
        self.assertEqual(advisory["assessment"], "needs_review")
        self.assertEqual(
            {source["source"] for source in advisory["sources"]},
            {"euvd", "nixos-tracker"},
        )
        self.assertTrue(advisory["sources"][1]["exploited"])
        self.assertEqual(report["components"][0]["version"], "0.13.5")

    def test_exact_product_and_package_bindings(self) -> None:
        def response(url: str) -> dict:
            if url.startswith(API.TRACKER):
                return {
                    "count": 1,
                    "next": None,
                    "results": [suggestion(package="libuv")],
                }
            return {"total": 1, "items": [entry(package="libuv")]}

        report = API.assess([self.component], FakeClient(response))
        self.assertEqual(report["advisories"], [])
        self.assertEqual({item["status"] for item in report["queries"]}, {"unknown"})

    def test_source_failure_keeps_independent_results(self) -> None:
        def response(url: str) -> dict:
            if url.startswith(API.EUVD):
                raise urllib.error.URLError("offline")
            return FakeClient.response(url)

        report = API.assess([self.component], FakeClient(response))
        self.assertEqual(report["status"], "incomplete")
        self.assertEqual(report["advisories"][0]["id"], CVE)
        self.assertEqual(report["errors"][0]["source"], "euvd")

    def test_exploitation_failure_keeps_euvd_candidates_with_unknown_exploitation(
        self,
    ) -> None:
        def response(url: str) -> dict:
            if "exploited=true" in url:
                raise urllib.error.HTTPError(url, 503, "unavailable", {}, None)
            return FakeClient.response(url)

        report = API.assess([self.component], FakeClient(response))
        self.assertEqual(report["status"], "incomplete")
        self.assertIsNone(report["advisories"][0]["sources"][1]["exploited"])
        self.assertEqual(report["errors"][0]["phase"], "exploitation")

    def test_tracker_pagination_and_foreign_next_link(self) -> None:
        def response(url: str) -> dict:
            query = urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)
            return {
                "count": 2,
                "next": None if "page" in query else url + "&page=2",
                "results": [suggestion("CVE-2026-12346" if "page" in query else CVE)],
            }

        self.assertEqual(len(API.tracker(FakeClient(response), "uv")), 2)
        for next_url in [
            "https://example.com/api/v1/suggestions?package=uv",
            API.TRACKER + "?package=other",
        ]:
            with (
                self.subTest(url=next_url),
                self.assertRaisesRegex(ValueError, "changed origin or package"),
            ):
                API.tracker(
                    FakeClient(
                        lambda _, next_url=next_url: {
                            "count": 2,
                            "next": next_url,
                            "results": [suggestion()],
                        }
                    ),
                    "uv",
                )
        with self.assertRaisesRegex(ValueError, "incomplete"):
            API.tracker(
                FakeClient(
                    lambda _: {"count": 2, "next": None, "results": [suggestion()]}
                ),
                "uv",
            )

    def test_euvd_pagination_and_repeated_or_missing_pages(self) -> None:
        def response(url: str) -> dict:
            second = urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)[
                "page"
            ] == ["1"]
            return {
                "total": 2,
                "items": [entry("EUVD-2026-2" if second else "EUVD-2026-1")],
            }

        self.assertEqual(len(API.euvd_items(FakeClient(response), "uv")), 2)
        with self.assertRaisesRegex(ValueError, "repeated"):
            API.euvd_items(FakeClient(lambda _: {"total": 2, "items": [entry()]}), "uv")
        with self.assertRaisesRegex(ValueError, "incomplete"):
            API.euvd_items(FakeClient(lambda _: {"total": 2, "items": []}), "uv")

    def test_bad_api_shape_is_incomplete(self) -> None:
        report = API.assess([self.component], FakeClient(lambda _: {"unexpected": []}))
        self.assertEqual(report["status"], "incomplete")
        self.assertEqual(len(report["errors"]), 2)

    def test_invalid_euvd_scores_are_not_accepted(self) -> None:
        for score in [float("nan"), -1, 11, "high"]:
            with self.subTest(score=score):

                def response(url: str, score: object = score) -> dict:
                    if url.startswith(API.TRACKER):
                        return FakeClient.response(url)
                    return {"total": 1, "items": [entry() | {"baseScore": score}]}

                report = API.assess([self.component], FakeClient(response))
                self.assertEqual(report["status"], "incomplete")

    def test_known_exploitation_is_ranked_first(self) -> None:
        exploited = entry("EUVD-2026-99999") | {"aliases": "CVE-2026-99999"}
        other = entry() | {"aliases": "CVE-2025-1000"}

        def response(url: str) -> dict:
            if url.startswith(API.TRACKER):
                return {"count": 0, "next": None, "results": []}
            items = [exploited] if "exploited=true" in url else [other, exploited]
            return {"total": len(items), "items": items}

        report = API.assess([self.component], FakeClient(response))
        self.assertEqual(report["advisories"][0]["id"], "CVE-2026-99999")

    def test_rate_limit_stops_repeated_requests_to_failed_source(self) -> None:
        def response(url: str) -> dict:
            if url.startswith(API.EUVD):
                raise urllib.error.HTTPError(url, 429, "rate limited", {}, None)
            return {"count": 0, "next": None, "results": []}

        client = FakeClient(response)
        report = API.assess(
            [self.component, {"name": "other", "version": "1", "reference": "other"}],
            client,
        )
        self.assertEqual(report["status"], "incomplete")
        self.assertEqual(
            sum(item["url"].startswith(API.EUVD) for item in client.requests), 1
        )
        self.assertIn("unavailable", {item["status"] for item in report["queries"]})

    def test_response_cache_refresh_and_expiry(self) -> None:
        with patch.object(
            API.urllib.request.OpenerDirector,
            "open",
            side_effect=lambda *_a, **_k: Response(b'{"items": [], "total": 0}'),
        ) as request:
            with patch.object(API.time, "time", return_value=100):
                client = API.Client(self.root / "cache")
                client.get(API.EUVD)
                client.get(API.EUVD)
                self.assertEqual(request.call_count, 1)
                self.assertTrue(client.requests[-1]["cached"])
                API.Client(self.root / "cache", refresh=True).get(API.EUVD)
                self.assertEqual(request.call_count, 2)
            with patch.object(API.time, "time", return_value=86501):
                client.get(API.EUVD)
                self.assertEqual(request.call_count, 3)
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            client.get("file:///etc/passwd")
        self.assertIsNone(
            API.NoRedirect().redirect_request(
                API.urllib.request.Request(API.EUVD),
                None,
                302,
                "redirect",
                {},
                "http://127.0.0.1/",
            )
        )

    def test_sbom_cli_never_builds_and_does_not_apply_vex(self) -> None:
        sbom = self.root / "sbom.json"
        sbom.write_text(
            json.dumps(
                {
                    "bomFormat": "CycloneDX",
                    "components": [{"name": "uv", "version": "0.13.5"}],
                }
            )
        )
        vex = self.root / "vex.json"
        vex.write_text(
            json.dumps(
                {
                    "@context": "https://openvex.dev/ns/v0.2.0",
                    "statements": [
                        {"vulnerability": {"name": CVE}, "status": "not_affected"}
                    ],
                }
            )
        )
        output = self.root / "report.json"
        with (
            patch.object(
                sys,
                "argv",
                [
                    "security-intel",
                    "--sbom",
                    str(sbom),
                    "--vex",
                    str(vex),
                    "--output",
                    str(output),
                ],
            ),
            patch.object(API, "Client", return_value=FakeClient()),
            patch.object(API.subprocess, "run") as process,
        ):
            self.assertEqual(API.main(), 0)
        process.assert_not_called()
        report = json.loads(output.read_text())
        self.assertFalse(report["vex_context"]["applied"])
        self.assertEqual(len(report["advisories"]), 1)

    def test_cli_rejects_flake_and_input_overwrite(self) -> None:
        output = self.root / "report.json"
        with (
            patch.object(
                sys,
                "argv",
                ["security-intel", "--target", str(self.root), "--output", str(output)],
            ),
            patch.object(API.subprocess, "run") as process,
        ):
            self.assertEqual(API.main(), 2)
        process.assert_not_called()
        before = output.read_bytes()
        with (
            patch.object(
                sys,
                "argv",
                ["security-intel", "--sbom", str(output), "--output", str(output)],
            ),
            self.assertRaises(SystemExit),
        ):
            API.main()
        self.assertEqual(output.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
