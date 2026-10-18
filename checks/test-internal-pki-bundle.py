#!/usr/bin/env python3
"""Check deployed CA bundles and the actual archive script's retry/retention behavior."""

import errno
import hashlib
import html
import io
import os
import pty
import re
import select
import signal
import ssl
import subprocess
import tempfile
import time
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


def check_install_commands():
    page = (ROOT / "certs/index.html").read_text()
    match = re.search(r'<pre id="debian-install"><code>(.*?)</code></pre>', page, re.S)
    script = html.unescape(match.group(1))
    assert (
        page[
            page.index('<section aria-labelledby="debian">') : page.index(
                '<section aria-labelledby="fingerprints">'
            )
        ].count("<pre")
        == 1
    )
    assert script in (ROOT / "docs/internal-pki.md").read_text()
    subprocess.run(["bash", "-n"], input=script, text=True, check=True)
    tools = subprocess.check_output(
        [
            "nix",
            "build",
            "--no-link",
            "--print-out-paths",
            "path:.#nixosConfigurations.proxy.pkgs.nssTools",
        ],
        cwd=ROOT,
        text=True,
    ).strip()
    certutil = str(Path(tools) / "bin/certutil")
    for choice, profile_count, expected_status in (
        (b"ja\n999\n2\n\n", 2, 0),
        (b"ja\n3\n", 2, 0),
        (b"ja\n", 0, 0),
        (b"nee\n", 2, 1),
    ):
        with tempfile.TemporaryDirectory(prefix="firefox-ca-menu-") as directory:
            home = Path(directory)
            commands = home / "bin"
            commands.mkdir()
            # Log privileged steps without changing packages or the host trust store.
            sudo = commands / "sudo"
            sudo.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$HOME/sudo-calls"\n')
            sudo.chmod(0o755)
            profiles = [
                home / ".mozilla/firefox" / name
                for name in ("1.default-esr", "2.profile with spaces")
            ][:profile_count]
            for profile in profiles:
                profile.mkdir(parents=True)
                subprocess.run(
                    [certutil, "-N", "-d", f"sql:{profile}", "--empty-password"],
                    check=True,
                )
            path = home / "install.sh"
            path.write_text(script)
            env = os.environ | {
                "HOME": str(home),
                "PATH": f"{commands}:{Path(tools) / 'bin'}:{os.environ['PATH']}",
            }
            pid, fd = pty.fork()
            if pid == 0:
                os.execvpe("bash", ["bash", str(path)], env)
            output = bytearray()
            try:
                os.write(fd, choice)
                deadline = time.monotonic() + 30
                while True:
                    if time.monotonic() > deadline:
                        os.kill(pid, signal.SIGKILL)
                        raise AssertionError("Installer menu timed out")
                    readable, _, _ = select.select([fd], [], [], 0.2)
                    if not readable:
                        continue
                    try:
                        chunk = os.read(fd, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        break
                    if not chunk:
                        break
                    output.extend(chunk)
            finally:
                os.close(fd)
                _, status = os.waitpid(pid, 0)
            assert os.waitstatus_to_exitcode(status) == expected_status, output.decode(
                errors="replace"
            )
            for name in FILES[:2]:
                assert (home / "Downloads" / name).read_bytes() == (
                    ROOT / "certs" / name
                ).read_bytes()
            calls = (home / "sudo-calls").read_text()
            if choice.startswith(b"nee"):
                assert not any(
                    line.startswith("install ") or line == "update-ca-certificates"
                    for line in calls.splitlines()
                )
            for index, profile in enumerate(profiles):
                certificates = subprocess.check_output(
                    [certutil, "-L", "-d", f"sql:{profile}"], text=True
                )
                imported = choice.startswith(b"ja\n999") and index == 1
                assert ("Powerlan Forgejo CA" in certificates) == imported, certificates
                assert ("Powerlan FreeIPA CA" in certificates) == imported, certificates
                if imported:
                    assert certificates.count("C,,") == 2, certificates
    print(
        "Firefox installer: profile selection, invalid input, skip, no profiles and fingerprint refusal passed"
    )


def check_https_site():
    context = ssl.create_default_context(cafile=str(ROOT / "certs/forgejo-ca.crt"))
    with urllib.request.urlopen(
        "https://192.168.2.111/", context=context, timeout=10
    ) as response:
        secure_page = response.read()
    plain_page, _, _ = download("/")
    assert secure_page == plain_page, (
        "HTTP and HTTPS serve different certificate instructions"
    )
    with urllib.request.urlopen(
        "https://192.168.2.111/forgejo-ca.crt", context=context, timeout=10
    ) as response:
        assert response.read() == (ROOT / "certs/forgejo-ca.crt").read_bytes()
    print(
        "Certificate website HTTPS: expected CA, IP address and published content verified"
    )


def main():
    check_https_site()
    check_install_commands()
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
