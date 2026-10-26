#!/usr/bin/env python3
"""Check freshness, credential boundaries and the sanitized monitoring API."""

import importlib.util
import json
import re
import sys
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
spec = importlib.util.spec_from_file_location(
    "homepage_monitor", Path(sys.path[0]) / "homepage-monitor.py"
)
assert spec is not None and spec.loader is not None
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)
maintenance_spec = importlib.util.spec_from_file_location(
    "openbao_maintenance", Path(sys.path[0]) / "openbao-maintain.py"
)
assert maintenance_spec is not None and maintenance_spec.loader is not None
maintenance = importlib.util.module_from_spec(maintenance_spec)
maintenance_spec.loader.exec_module(maintenance)


class MonitoringTests(unittest.TestCase):
    def test_policy_excludes_ldap_passwords_and_wildcard_access(self) -> None:
        policy = (
            Path(__file__).resolve().parents[1] / "features/homepage/policy.hcl"
        ).read_text()
        paths = re.findall(r'path "([^"]+)"', policy)
        self.assertEqual(
            set(paths),
            {
                "services/data/homepage/proxmox",
                "services/data/homepage/pihole",
                "status/data/forgejo-reader",
                "status/data/proxmox-reader",
                "ldap/static-role/forgejo-reader",
                "ldap/static-role/proxmox-reader",
                "auth/token/revoke-self",
            },
        )
        self.assertEqual(policy.count('["read"]'), 6)
        self.assertEqual(policy.count('["update"]'), 1)
        self.assertNotIn("static-cred", policy)
        self.assertNotIn("*", policy)

    def test_freshness_rejects_stale_future_and_invalid_values(self) -> None:
        for invalid in (None, True, "100", float("nan"), float("inf"), 0, 301, -1):
            self.assertFalse(monitor.fresh(invalid, 60, 100), invalid)
        self.assertTrue(monitor.fresh(99, 60, 100))

    def test_certificate_error_is_sanitized_and_does_not_escape(self) -> None:
        with mock.patch.object(
            monitor.socket,
            "create_connection",
            side_effect=OSError("private diagnostic"),
        ):
            name, value = monitor.certificate(("home", "home.powerlan.empire"))
        self.assertEqual((name, value["status"], value["days"]), ("home", "Fout", "?"))
        self.assertNotIn("private", json.dumps(value))

    def test_env_has_only_own_credentials_and_rejects_injection(self) -> None:
        proxmox = {
            "username": "homepage@pve!dashboard",
            "password": "token-value-12345",
        }
        value = monitor.environment(proxmox, {"password": "app-password-12345"})
        self.assertEqual(value.count(b"\n"), 3)
        self.assertNotIn(b"BAO_TOKEN", value)
        for invalid in ("x\nHOME=evil", "$(id)", 'bad"value', "", "a"):
            with self.assertRaises(ValueError):
                monitor.environment(proxmox, {"password": invalid})
        with self.assertRaises(ValueError):
            monitor.environment(
                proxmox | {"username": "root@pam!admin"},
                {"password": "app-password-12345"},
            )

    def test_backup_requires_recent_report_and_successful_backup(self) -> None:
        data = {"checked_at": 10000, "last_success": 9000, "result": "success"}
        self.assertEqual(monitor.backup(data, 10000)["status"], "OK")
        for changes in (
            {"checked_at": 0},
            {"last_success": 0},
            {"result": "exit-code"},
        ):
            self.assertEqual(monitor.backup(data | changes, 10000)["status"], "Fout")

    def test_ldap_and_rotation_exclude_password_fingerprints(self) -> None:
        now = time.time()
        stamp = monitor.dt.datetime.fromtimestamp(
            now - 3600, monitor.dt.UTC
        ).isoformat()
        client = mock.Mock()
        client.request.side_effect = lambda path: (
            {"data": {"data": {"applied_at": now - 30, "password_sha256": "private"}}}
            if path.startswith("status/")
            else {"data": {"last_vault_rotation": stamp}}
        )
        ldap, rotation = monitor.rotation(client, now)
        self.assertEqual((ldap["status"], rotation["status"]), ("OK", "OK"))
        self.assertNotIn("private", json.dumps([ldap, rotation]))
        self.assertEqual(monitor.rotation(client, now + 100000)[0]["status"], "Fout")

    def test_api_never_serves_stale_status_or_private_files(self) -> None:
        with (
            tempfile.TemporaryDirectory() as temporary,
            mock.patch.object(monitor, "RUNTIME", Path(temporary)),
        ):
            path = Path(temporary) / "status.json"
            path.write_text(
                json.dumps({"checked_at": time.time(), "dns": {"status": "OK"}})
            )
            (Path(temporary) / "credentials.env").write_text("SECRET=private")
            server = monitor.http.server.ThreadingHTTPServer(
                ("127.0.0.1", 0), monitor.Handler
            )
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                address = f"http://127.0.0.1:{server.server_port}"
                with urllib.request.urlopen(  # noqa: S310 -- Disposable loopback fixture.
                    address + "/status.json", timeout=3
                ) as response:
                    self.assertEqual(json.load(response)["dns"]["status"], "OK")
                for name in ("credentials.env", "../credentials.env"):
                    with self.assertRaises(urllib.error.HTTPError) as caught:
                        urllib.request.urlopen(address + "/" + name, timeout=3)  # noqa: S310 -- Disposable loopback fixture.
                    self.assertEqual(caught.exception.code, 404)
                path.write_text(json.dumps({"checked_at": time.time() - 181}))
                with self.assertRaises(urllib.error.HTTPError) as caught:
                    urllib.request.urlopen(address + "/status.json", timeout=3)  # noqa: S310 -- Disposable loopback fixture.
                self.assertEqual(caught.exception.code, 503)
            finally:
                server.shutdown()
                server.server_close()
                thread.join()


if __name__ == "__main__":
    unittest.main()
