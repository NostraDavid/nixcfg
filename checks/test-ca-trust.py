#!/usr/bin/env python3
"""Exercise real compromised chains, package bundles, and the local repair."""

import base64
import csv
import hashlib
import io
import os
import runpy
import shutil
import ssl
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

REPAIR = runpy.run_path(os.environ["CA_REPAIR_SCRIPT"])
OPENSSL = shutil.which("openssl")
if OPENSSL is None:
    raise RuntimeError("OpenSSL is required")


class CertificateTrustTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        with zipfile.ZipFile(os.environ["CA_OLD_CERTIFI"]) as archive:
            self.old = archive.read("certifi/cacert.pem")
        self.private = Path(os.environ["CA_PRIVATE_ROOT"]).read_bytes()

    def verify_chains(self, bundle: Path, accepted: bool) -> None:
        with zipfile.ZipFile(os.environ["CA_CHAINS"]) as archive:
            names = [name for name in archive.namelist() if name.endswith(".pem")]
            self.assertEqual(len(names), 14)
            for name in names:
                path = self.root / Path(name).name
                path.write_bytes(archive.read(name))
                result = subprocess.run(  # noqa: S603
                    [
                        OPENSSL,
                        "verify",
                        "-no-CApath",
                        "-no-CAstore",
                        "-purpose",
                        "sslserver",
                        "-attime",
                        "1792713600",  # Freeze verification time for these October 2026 fixtures.
                        "-CAfile",
                        str(bundle),
                        "-untrusted",
                        str(path),
                        str(path),
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=10,
                )
                if accepted:
                    self.assertEqual(result.returncode, 0, result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0, name)
                    self.assertRegex(result.stderr, r"error (?:20|27|28) at")

    def test_original_issue_and_all_cross_signs(self) -> None:
        bundle = self.root / "old.pem"
        bundle.write_bytes(self.old)
        self.verify_chains(bundle, accepted=True)
        bundle.write_bytes(REPAIR["filter_bundle"](self.old + self.private))
        self.verify_chains(bundle, accepted=False)
        self.assertIn(self.private, bundle.read_bytes())

    def test_repair_metadata_backup_and_idempotence(self) -> None:
        site = self.root / "site-packages"
        bundle = site / "certifi/cacert.pem"
        bundle.parent.mkdir(parents=True)
        bundle.write_bytes(self.old + self.private)
        bundle.chmod(0o640)
        record = site / "certifi-2024.8.30.dist-info/RECORD"
        record.parent.mkdir()
        record.write_text("certifi/cacert.pem,,\n", encoding="utf-8")
        self.assertTrue(REPAIR["repair_file"](bundle, False))
        self.assertEqual(bundle.read_bytes(), self.old + self.private)
        self.assertEqual(list(site.rglob("*.before-emudhra")), [])
        self.assertTrue(REPAIR["repair_file"](bundle, True))
        self.assertFalse(REPAIR["repair_file"](bundle, True))
        self.assertEqual(bundle.stat().st_mode & 0o777, 0o640)
        self.assertEqual(
            bundle.with_name("cacert.pem.before-emudhra").read_bytes(),
            self.old + self.private,
        )
        row = next(csv.reader(io.StringIO(record.read_text())))
        digest = (
            base64.urlsafe_b64encode(hashlib.sha256(bundle.read_bytes()).digest())
            .rstrip(b"=")
            .decode("ascii")
        )
        self.assertEqual(row[1:], ["sha256=" + digest, str(bundle.stat().st_size)])
        self.assertIn(self.private, bundle.read_bytes())
        record.write_bytes(record.read_bytes().replace(b"\n", b"\r\n"))
        original_record = record.read_bytes()
        self.assertFalse(REPAIR["repair_file"](bundle, True))
        self.assertEqual(record.read_bytes(), original_record)

    def test_ensurepip_wheel_repair(self) -> None:
        path = self.root / "pip-25.0.whl"
        name = "pip/_vendor/certifi/cacert.pem"
        record = "pip-25.0.dist-info/RECORD"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr(name, self.old)
            archive.writestr(record, name + ",,\n")
            archive.writestr("pip/untouched.py", "original")
        before = path.read_bytes()
        self.assertTrue(REPAIR["repair_wheel"](path, False))
        self.assertEqual(path.read_bytes(), before)
        self.assertTrue(REPAIR["repair_wheel"](path, True))
        self.assertFalse(REPAIR["repair_wheel"](path, True))
        with zipfile.ZipFile(path) as archive:
            self.assertEqual(archive.read("pip/untouched.py"), b"original")
            self.assertEqual(archive.read(name), REPAIR["filter_bundle"](self.old))

    def test_invalid_input_and_symlinks_do_not_mutate(self) -> None:
        path = self.root / "bundle.pem"
        path.write_bytes(self.old)
        link = self.root / "link.pem"
        link.symlink_to(path)
        with self.assertRaisesRegex(ValueError, "symlink"):
            REPAIR["repair_file"](link, True)
        self.assertEqual(path.read_bytes(), self.old)
        self.assertEqual(list(self.root.glob("*.before-emudhra")), [])
        with self.assertRaises(ValueError):
            REPAIR["filter_bundle"](b"not a certificate")

    def test_backup_interruption_preserves_original_and_retry(self) -> None:
        path = self.root / "bundle.pem"
        path.write_bytes(self.old)

        def interrupt(_source: Path, destination: Path) -> None:
            destination.write_bytes(b"partial")
            raise OSError("Simulated interrupted copy")

        with patch("shutil.copy2", interrupt), self.assertRaises(OSError):
            REPAIR["atomic_write"](path, b"new data")
        self.assertEqual(path.read_bytes(), self.old)
        self.assertEqual(list(self.root.glob("*.before-emudhra")), [])
        REPAIR["atomic_write"](path, b"new data")
        self.assertEqual(
            path.with_name("bundle.pem.before-emudhra").read_bytes(), self.old
        )

    def test_real_package_bundles(self) -> None:
        for bundle in os.environ["CA_BUNDLES"].split():
            with self.subTest(bundle=bundle):
                self.verify_chains(Path(bundle), accepted=False)

    def test_bootstrap_pip(self) -> None:
        for root in os.environ["CA_SEEDED_PIP"].split():
            bundles = list(
                Path(root).glob(
                    "lib/python*/site-packages/pip/_vendor/certifi/cacert.pem"
                )
            )
            self.assertEqual(len(bundles), 1, root)
            self.verify_chains(bundles[0], accepted=False)
        import ensurepip  # noqa: PLC0415

        self.assertGreaterEqual(
            tuple(map(int, ensurepip.version().split("."))), (26, 2, 2)
        )
        wheel = next((Path(ensurepip.__file__).parent / "_bundled").glob("pip-*.whl"))
        with zipfile.ZipFile(wheel) as archive:
            bundle = self.root / "ensurepip.pem"
            bundle.write_bytes(archive.read("pip/_vendor/certifi/cacert.pem"))
        self.verify_chains(bundle, accepted=False)

    def test_actual_node_version_and_builtin_roots(self) -> None:
        node = str(Path(os.environ["CA_NODE_PACKAGE"]) / "bin/node")
        version = subprocess.run(  # noqa: S603
            [node, "--version"], capture_output=True, text=True, check=True, timeout=10
        ).stdout.strip()
        self.assertTrue(version.startswith("v24."), version)
        if tuple(map(int, version[1:].split("."))) < (24, 22, 1):
            self.skipTest("Pinned nixpkgs Node predates the upstream security release")
        roots = subprocess.run(  # noqa: S603
            [
                node,
                "--input-type=module",
                "-e",
                "import {rootCertificates} from 'node:tls'; process.stdout.write(rootCertificates.join('\\n'));",
            ],
            capture_output=True,
            check=True,
            timeout=10,
        ).stdout
        bundle = self.root / "node-builtin.pem"
        bundle.write_bytes(roots)
        self.verify_chains(bundle, accepted=False)

    def test_seeded_pip_truststore_context(self) -> None:
        bundle = self.root / "filtered.pem"
        bundle.write_bytes(REPAIR["filter_bundle"](self.old + self.private))
        empty = self.root / "empty"
        empty.mkdir()
        environment = os.environ | {
            "SSL_CERT_FILE": str(bundle),
            "SSL_CERT_DIR": str(empty),
            "PIP_CERT": str(bundle),
        }
        for root in os.environ["CA_SEEDED_PIP"].split():
            with self.subTest(root=root):
                result = subprocess.run(  # noqa: S603
                    [
                        str(Path(root) / "bin/python"),
                        "-c",
                        (
                            "from pip._internal.cli.index_command import _create_truststore_ssl_context; "
                            "import base64, os, ssl; "
                            "ctx = _create_truststore_ssl_context(); "
                            "ctx.load_verify_locations(os.environ['PIP_CERT']); "
                            "ctx.wrap_bio(ssl.MemoryBIO(), ssl.MemoryBIO(), server_hostname='example.com'); "
                            "print('\\n'.join(base64.b64encode(c).decode() for c in ctx._ctx.get_ca_certs(binary_form=True)))"
                        ),
                    ],
                    capture_output=True,
                    text=True,
                    check=True,
                    timeout=10,
                    env=environment,
                )
                certificates = [
                    base64.b64decode(line) for line in result.stdout.splitlines()
                ]
                context_bundle = self.root / "pip-context.pem"
                context_bundle.write_text(
                    "".join(ssl.DER_cert_to_PEM_cert(der) for der in certificates)
                )
                self.verify_chains(context_bundle, accepted=False)
                self.assertIn(
                    hashlib.sha256(
                        ssl.PEM_cert_to_DER_cert(self.private.decode())
                    ).hexdigest(),
                    {hashlib.sha256(der).hexdigest() for der in certificates},
                )


if __name__ == "__main__":
    unittest.main()
