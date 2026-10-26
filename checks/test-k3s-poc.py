#!/usr/bin/env python3
"""Exercise the POC's real HTTP readiness and secret redaction."""

import importlib.util
import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("poc", ROOT / "features/k3s/poc.py")
assert spec is not None and spec.loader is not None
poc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(poc)


class PocTests(unittest.TestCase):
    def test_rejects_missing_invalid_and_oversized_secret(self) -> None:
        with (
            tempfile.TemporaryDirectory() as directory,
            mock.patch.object(poc, "SECRET", Path(directory) / "secret"),
        ):
            self.assertFalse(poc.ready())
            for data in (
                b"bad json",
                b"[]",
                b'{"value":1}',
                b'{"value":"short"}',
                b" " * 4097,
            ):
                poc.SECRET.write_bytes(data)
                self.assertFalse(poc.ready())
            poc.SECRET.write_text(
                json.dumps({"value": "fixture-secret-with-sufficient-length"})
            )
            self.assertTrue(poc.ready())

    def test_http_reflects_readiness_without_exposing_values(self) -> None:
        with (
            tempfile.TemporaryDirectory() as directory,
            mock.patch.object(poc, "SECRET", Path(directory) / "secret"),
        ):
            server = poc.http.server.ThreadingHTTPServer(("127.0.0.1", 0), poc.Handler)
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            address = f"http://127.0.0.1:{server.server_port}"
            try:
                with self.assertRaises(urllib.error.HTTPError) as missing:
                    urllib.request.urlopen(address + "/healthz", timeout=3)  # noqa: S310 -- Local fixture only.
                self.assertEqual(missing.exception.code, 503)
                fixture = "fixture-poc-secret-never-in-a-response"
                poc.SECRET.write_text(json.dumps({"value": fixture}))
                for path in ("/", "/healthz"):
                    with urllib.request.urlopen(address + path, timeout=3) as response:  # noqa: S310 -- Local fixture only.
                        content = response.read()
                        self.assertEqual(response.status, 200)
                        self.assertNotIn(fixture.encode(), content)
                with self.assertRaises(urllib.error.HTTPError) as private:
                    urllib.request.urlopen(address + "/probe.json", timeout=3)  # noqa: S310 -- Local fixture only.
                self.assertEqual(private.exception.code, 404)
            finally:
                server.shutdown()
                server.server_close()
                worker.join()

    def test_html_escapes_workload_metadata(self) -> None:
        with (
            tempfile.TemporaryDirectory() as directory,
            mock.patch.object(poc, "SECRET", Path(directory) / "secret"),
        ):
            poc.SECRET.write_text('{"value":"fixture-contains-no-real-secret"}')
            server = poc.http.server.ThreadingHTTPServer(("127.0.0.1", 0), poc.Handler)
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            try:
                with (
                    mock.patch.dict(os.environ, {"POD_NAME": "<script>bad</script>"}),
                    urllib.request.urlopen(
                        f"http://127.0.0.1:{server.server_port}/", timeout=3
                    ) as response,
                ):
                    body = response.read()
                self.assertNotIn(b"<script>", body)
                self.assertIn(b"&lt;script&gt;", body)
            finally:
                server.shutdown()
                server.server_close()
                worker.join()


if __name__ == "__main__":
    unittest.main()
