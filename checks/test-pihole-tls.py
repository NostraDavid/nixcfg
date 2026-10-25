#!/usr/bin/env python3
"""Exercise real certificate validation, idempotence and failed-install recovery."""

import importlib.util
import io
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "pihole_tls", Path(__file__).resolve().parents[1] / "scripts/pihole-tls.py"
)
assert spec is not None and spec.loader is not None
pihole_tls = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pihole_tls)


class CertificateTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name in ("AUTHORITY", "PUBLIC", "TARGET", "PREVIOUS"):
            value = self.root if name == "AUTHORITY" else self.root / name.lower()
            patcher = mock.patch.object(pihole_tls, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.ca = self.root / "root.crt"
        pihole_tls.run(
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "ec",
            "-pkeyopt",
            "ec_paramgen_curve:P-384",
            "-nodes",
            "-days",
            "730",
            "-subj",
            "/CN=Test CA",
            "-addext",
            "basicConstraints=critical,CA:TRUE",
            "-keyout",
            str(self.root / "root.key"),
            "-out",
            str(self.ca),
        )
        self.request = self.root / "request.csr"
        self.key = self.root / "server.key"
        pihole_tls.run(
            "openssl",
            "req",
            "-new",
            "-newkey",
            "ec",
            "-pkeyopt",
            "ec_paramgen_curve:P-384",
            "-nodes",
            "-subj",
            "/CN=pihole.powerlan.empire",
            "-keyout",
            str(self.key),
            "-out",
            str(self.request),
        )
        pihole_tls.publish(self.request)
        self.certificate = pihole_tls.PUBLIC.read_bytes()
        self.original = self.certificate + self.ca.read_bytes() + self.key.read_bytes()
        pihole_tls.TARGET.write_bytes(self.original)
        pihole_tls.TARGET.chmod(0o600)

    def test_publisher_is_idempotent_and_public(self) -> None:
        before = pihole_tls.PUBLIC.stat().st_mtime_ns
        pihole_tls.publish(self.request)
        self.assertEqual(pihole_tls.PUBLIC.read_bytes(), self.certificate)
        self.assertEqual(pihole_tls.PUBLIC.stat().st_mtime_ns, before)
        self.assertNotIn(b"PRIVATE KEY", self.certificate)
        self.assertEqual(pihole_tls.PUBLIC.stat().st_mode & 0o777, 0o644)
        pihole_tls.verify(self.certificate, self.ca)

    def test_rejects_wrong_key_and_private_material(self) -> None:
        wrong_key = pihole_tls.run(
            "openssl", "pkey", "-in", str(self.root / "root.key"), "-pubout"
        )
        with self.assertRaisesRegex(ValueError, "does not match"):
            pihole_tls.verify(self.certificate, self.ca, wrong_key)
        with self.assertRaisesRegex(ValueError, "public certificate only"):
            pihole_tls.verify(self.original, self.ca)

    def test_rejects_wrong_authority_and_expiring_certificate(self) -> None:
        other_ca = self.root / "other.crt"
        pihole_tls.run(
            "openssl",
            "req",
            "-x509",
            "-key",
            str(self.key),
            "-days",
            "730",
            "-subj",
            "/CN=Other CA",
            "-addext",
            "basicConstraints=critical,CA:TRUE",
            "-out",
            str(other_ca),
        )
        with self.assertRaises(subprocess.CalledProcessError):
            pihole_tls.verify(self.certificate, other_ca)
        with self.assertRaises(subprocess.CalledProcessError):
            pihole_tls.verify(self.certificate, self.ca, days=366)

    def test_failed_restart_restores_private_pem(self) -> None:
        pihole_tls.PUBLIC.unlink()
        pihole_tls.publish(self.request)
        candidate = pihole_tls.PUBLIC.read_bytes()
        actual_run = pihole_tls.run

        def run(*command: str, **kwargs: object) -> bytes:
            if command[0] == "systemctl":
                return b""
            return actual_run(*command, **kwargs)

        with (
            mock.patch.object(pihole_tls, "download", return_value=candidate),
            mock.patch.object(
                pihole_tls, "healthy", side_effect=ValueError("Old certificate")
            ),
            mock.patch.object(
                pihole_tls, "wait_healthy", side_effect=OSError("No listener")
            ),
            mock.patch.object(pihole_tls, "run", side_effect=run),
            self.assertRaisesRegex(RuntimeError, "restored"),
        ):
            pihole_tls.renew(self.ca)
        self.assertEqual(pihole_tls.TARGET.read_bytes(), self.original)
        self.assertEqual(pihole_tls.TARGET.stat().st_mode & 0o777, 0o600)
        self.assertEqual(pihole_tls.TARGET.stat().st_uid, os.getuid())
        self.assertEqual(pihole_tls.PREVIOUS.read_bytes(), self.original)

    def test_download_failure_leaves_existing_certificate_untouched(self) -> None:
        before = pihole_tls.TARGET.stat().st_mtime_ns
        with (
            mock.patch.object(pihole_tls, "download", side_effect=OSError("Offline")),
            self.assertRaises(OSError),
        ):
            pihole_tls.renew(self.ca)
        self.assertEqual(pihole_tls.TARGET.read_bytes(), self.original)
        self.assertEqual(pihole_tls.TARGET.stat().st_mtime_ns, before)

    def test_failed_report_is_visible_without_secret_details(self) -> None:
        with (
            mock.patch.object(pihole_tls, "inspect", side_effect=OSError("Offline")),
            self.assertRaises(OSError),
        ):
            pihole_tls.report(self.ca)
        data = pihole_tls.PUBLIC.with_name("status.json").read_bytes()
        state = json.loads(data)
        self.assertEqual(state["status"], "Fout")
        self.assertNotIn(b"PRIVATE KEY", data)
        self.assertNotIn(b"Offline", data)

    def test_report_and_stale_status_detection(self) -> None:
        with mock.patch.object(
            pihole_tls, "inspect", return_value=time.time() + 365 * 86400
        ):
            pihole_tls.report(self.ca)
        state = json.loads(pihole_tls.PUBLIC.with_name("status.json").read_bytes())
        self.assertEqual(state["status"], "OK")
        self.assertEqual(state["days"], 365)
        with mock.patch.object(
            pihole_tls.urllib.request,
            "urlopen",
            return_value=io.BytesIO(json.dumps(state).encode()),
        ):
            pihole_tls.check_status(
                self.ca, "https://192.168.2.111/pihole-tls/status.json", 7200
            )
        state["checked"] = "2020-01-01T00:00:00+00:00"
        with (
            mock.patch.object(
                pihole_tls.urllib.request,
                "urlopen",
                return_value=io.BytesIO(json.dumps(state).encode()),
            ),
            self.assertRaisesRegex(ValueError, "stale"),
        ):
            pihole_tls.check_status(
                self.ca, "https://192.168.2.111/pihole-tls/status.json", 7200
            )

    def test_job_status_records_failure_and_success(self) -> None:
        status = self.root / "job.json"
        with self.assertRaises(RuntimeError), pihole_tls.status_file(status):
            raise RuntimeError("Failed")
        self.assertEqual(json.loads(status.read_bytes())["status"], "Fout")
        with pihole_tls.status_file(status):
            pass
        self.assertEqual(json.loads(status.read_bytes())["status"], "OK")


if __name__ == "__main__":
    unittest.main()
