#!/usr/bin/env python3
"""Check deployed CA bundles and the actual archive script's retry/retention behavior."""

import hashlib
import io
import ssl
import subprocess
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE = "http://192.168.2.111"
FILES = ["freeipa.crt", "forgejo-ca.crt", "SHA256SUMS", "fingerprints.txt"]
VERSION = (ROOT / "certs" / "VERSION").read_text().strip()


def download(path):
    with urllib.request.urlopen(BASE + path, timeout=10) as response:
        return response.read(), response.geturl(), response.headers


def main():
    for extension in ["zip", "pem"]:
        latest_headers = subprocess.check_output(
            [
                "curl",
                "--fail",
                "--silent",
                "--show-error",
                "--head",
                BASE + f"/powerlan-ca-latest.{extension}",
            ],
            text=True,
        )
        assert "cache-control: no-store" in latest_headers.lower()
    archive, url, headers = download("/powerlan-ca-latest.zip")
    release = f"/releases/{VERSION}"
    assert url == BASE + release + "/powerlan-ca.zip", url
    assert "immutable" in headers.get("Cache-Control", "")
    checksum, _, _ = download(release + "/powerlan-ca.zip.sha256")
    assert (
        checksum.decode().strip()
        == hashlib.sha256(archive).hexdigest() + "  powerlan-ca.zip"
    )
    pem, pem_url, _ = download("/powerlan-ca-latest.pem")
    assert pem_url == BASE + release + "/powerlan-ca.pem"
    assert pem == b"".join((ROOT / "certs" / name).read_bytes() for name in FILES[:2])
    assert len(ssl.create_default_context(cadata=pem.decode()).get_ca_certs()) == 2
    with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
        expected = {
            "freeipa.crt",
            "forgejo-ca.crt",
            "powerlan-ca.pem",
            "fingerprints.txt",
            "version.txt",
        }
        assert set(bundle.namelist()) == expected | {"SHA256SUMS"}
        assert bundle.read("version.txt").decode().strip() == VERSION
        assert bundle.read("powerlan-ca.pem") == pem
        for name in ["freeipa.crt", "forgejo-ca.crt", "fingerprints.txt"]:
            assert bundle.read(name) == (ROOT / "certs" / name).read_bytes(), name
        sums = dict(
            line.split("  ", 1)[::-1]
            for line in bundle.read("SHA256SUMS").decode().splitlines()
        )
        assert set(sums) == expected
        for name, digest in sums.items():
            assert hashlib.sha256(bundle.read(name)).hexdigest() == digest, name
    _, _, index_headers = download("/releases/")
    assert index_headers.get("Cache-Control") == "no-store"

    script = subprocess.check_output(
        [
            "nix",
            "eval",
            "--raw",
            "path:.#nixosConfigurations.proxy.config.systemd.services.certificate-releases.script",
        ],
        cwd=ROOT,
        text=True,
    )
    assert VERSION in script and "/srv/proxy/certificates" in script
    with tempfile.TemporaryDirectory(prefix="internal-ca-archive-") as directory:
        local = script.replace("/srv/proxy/certificates", directory)
        subprocess.run(["bash", "-euo", "pipefail", "-c", local], check=True)
        first = Path(directory) / "releases" / VERSION
        assert (first / "powerlan-ca.zip").read_bytes() == archive
        marker = first / "retention-check"
        marker.write_text("keep existing releases")
        subprocess.run(["bash", "-euo", "pipefail", "-c", local], check=True)
        assert marker.exists(), "Retry replaced an existing release"
        checksum_file = first / "powerlan-ca.zip.sha256"
        original_checksum = checksum_file.read_bytes()
        checksum_file.write_text("0" * 64 + "  powerlan-ca.zip\n")
        rejected = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", local], capture_output=True, text=True
        )
        assert rejected.returncode != 0 and "certs/VERSION" in rejected.stderr
        assert checksum_file.read_bytes() != original_checksum, (
            "Existing release was overwritten"
        )
        checksum_file.write_bytes(original_checksum)
        second_version = "2.0.0" if VERSION != "2.0.0" else "3.0.0"
        subprocess.run(
            ["bash", "-euo", "pipefail", "-c", local.replace(VERSION, second_version)],
            check=True,
        )
        assert marker.exists(), (
            "Publishing another release removed the previous release"
        )
        assert (
            Path(directory) / "releases" / second_version / "powerlan-ca.zip"
        ).exists()
        assert not list(Path(directory).glob(".release.*")), (
            "Staging directory was not cleaned up"
        )
    print(
        f"Bundle {VERSION}: downloads, PEM trust, checksums, immutable versions and release retention pass."
    )


if __name__ == "__main__":
    main()
