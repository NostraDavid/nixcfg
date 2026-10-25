#!/usr/bin/env python3
"""Publish, install and monitor Pi-hole certificates without transferring keys."""

import argparse
import contextlib
import datetime as dt
import http.client
import json
import math
import os
import re
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.request
from collections.abc import Iterator
from pathlib import Path

NAMES = ("pi.hole", "pihole.powerlan.empire", "192.168.2.102")
SOURCE = "https://192.168.2.113/pihole-tls/server.crt"
AUTHORITY = Path("/srv/certs/caddy/.local/share/caddy/pki/authorities/local")
PUBLIC = Path("/srv/certs/certificates/pihole-tls/server.crt")
TARGET = Path("/etc/pihole/tls.pem")
PREVIOUS = Path("/var/lib/pihole-tls/previous.pem")
GUEST_STATUS = Path("/var/www/html/admin/powerlan-tls-status.json")


def run(*command: str, data: bytes | None = None, timeout: int = 30) -> bytes:
    return subprocess.run(  # noqa: S603 -- Executables are fixed at every call site.
        command, input=data, capture_output=True, check=True, timeout=timeout
    ).stdout


def atomic(
    path: Path, data: bytes, mode: int, owner: tuple[int, int] | None = None
) -> None:
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as output:
        staging = Path(output.name)
        try:
            os.fchmod(output.fileno(), mode)
            if owner is not None:
                os.fchown(output.fileno(), *owner)
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
            staging.replace(path)
            directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        finally:
            staging.unlink(missing_ok=True)


def leaf(pem: bytes) -> bytes:
    match = re.search(
        rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", pem, re.DOTALL
    )
    if match is None:
        raise ValueError("Missing PEM certificate")
    return match.group() + b"\n"


@contextlib.contextmanager
def status_file(path: Path) -> Iterator[dict[str, str | int]]:
    state: dict[str, str | int] = {
        "status": "Fout",
        "days": "?",
        "checked": dt.datetime.now(dt.UTC).isoformat(),
    }
    try:
        yield state
        state["status"] = "OK"
    finally:
        atomic(path, json.dumps(state).encode(), 0o644)


def verify(
    certificate: bytes, ca: Path, public_key: bytes | None = None, days: int = 7
) -> None:
    if len(certificate) > 65536 or b"PRIVATE KEY" in certificate:
        raise ValueError("Expected a public certificate only")
    run("openssl", "x509", "-checkend", str(days * 86400), "-noout", data=certificate)
    for name in NAMES:
        option = "-verify_ip" if name == "192.168.2.102" else "-verify_hostname"
        run(
            "openssl",
            "verify",
            "-CAfile",
            str(ca),
            "-no-CApath",
            "-no-CAstore",
            "-purpose",
            "sslserver",
            option,
            name,
            data=certificate,
        )
    if public_key is not None:
        actual = run("openssl", "x509", "-pubkey", "-noout", data=certificate)
        if actual != public_key:
            raise ValueError("Certificate does not match the existing Pi-hole key")


def publish(request: Path) -> None:
    ca = AUTHORITY / "root.crt"
    run("openssl", "x509", "-in", str(ca), "-checkend", str(366 * 86400), "-noout")
    run("openssl", "req", "-in", str(request), "-verify", "-noout")
    public_key = run("openssl", "req", "-in", str(request), "-pubkey", "-noout")
    if PUBLIC.exists():
        try:
            verify(PUBLIC.read_bytes(), ca, public_key, days=30)
            print("Published certificate is current; no signing needed")
            return
        except (ValueError, subprocess.SubprocessError):
            pass
    with tempfile.TemporaryDirectory() as directory:
        extensions = Path(directory) / "extensions"
        extensions.write_text(
            "basicConstraints=critical,CA:FALSE\n"
            "keyUsage=critical,digitalSignature\n"
            "extendedKeyUsage=serverAuth\n"
            "subjectAltName=DNS:pi.hole,DNS:pihole.powerlan.empire,IP:192.168.2.102\n"
        )
        serial = "0x" + os.urandom(16).hex()
        certificate = run(
            "openssl",
            "x509",
            "-req",
            "-in",
            str(request),
            "-CA",
            str(ca),
            "-CAkey",
            str(AUTHORITY / "root.key"),
            "-set_serial",
            serial,
            "-days",
            "365",
            "-sha256",
            "-extfile",
            str(extensions),
        )
    verify(certificate, ca, public_key)
    atomic(PUBLIC, certificate, 0o644)
    print("Published a new 365-day Pi-hole certificate")


def download(ca: Path) -> bytes:
    with urllib.request.urlopen(
        SOURCE, context=ssl.create_default_context(cafile=str(ca)), timeout=15
    ) as response:
        certificate = response.read(65537)
    verify(certificate, ca)
    return certificate


def healthy(ca: Path, certificate: bytes, address: str) -> float:
    context = ssl.create_default_context(cafile=str(ca))
    expected = ssl.PEM_cert_to_DER_cert(leaf(certificate).decode())
    for name in NAMES:
        with (
            socket.create_connection((address, 443), timeout=5) as connection,
            context.wrap_socket(connection, server_hostname=name) as tls,
        ):
            if tls.getpeercert(binary_form=True) != expected:
                raise ValueError("Pi-hole has not loaded the published certificate")
            expires = ssl.cert_time_to_seconds(tls.getpeercert()["notAfter"])
            if expires < time.time() + 7 * 86400:
                raise ValueError("Pi-hole certificate expires within seven days")
            tls.sendall(
                f"GET /admin/login HTTP/1.1\r\nHost: {name}\r\nConnection: close\r\n\r\n".encode()
            )
            with http.client.HTTPResponse(tls) as response:
                response.begin()
                if response.status != 200:
                    raise ValueError(
                        f"Pi-hole login page returned HTTP {response.status}"
                    )
    return expires


def inspect(ca: Path) -> float:
    certificate = download(ca)
    verify(certificate, ca, days=21)
    check_status(ca, "https://192.168.2.113/pihole-tls/published.json", 48 * 3600)
    check_status(ca, "https://192.168.2.102/admin/powerlan-tls-status.json", 48 * 3600)
    return healthy(ca, certificate, "192.168.2.102")


def report(ca: Path) -> None:
    with status_file(PUBLIC.with_name("status.json")) as state:
        expires = inspect(ca)
        state["days"] = math.ceil((expires - time.time()) / 86400)
        state["expires"] = dt.datetime.fromtimestamp(expires, dt.UTC).isoformat()


def check_status(ca: Path, url: str, maximum_age: int) -> None:
    with urllib.request.urlopen(  # noqa: S310 -- Callers use fixed HTTPS endpoints only.
        url,
        context=ssl.create_default_context(cafile=str(ca)),
        timeout=15,
    ) as response:
        data = response.read(4097)
    try:
        if len(data) > 4096:
            raise ValueError("Oversized report")
        state = json.loads(data)
        checked = dt.datetime.fromisoformat(state["checked"]).timestamp()
        if state["status"] != "OK" or not -300 <= time.time() - checked < maximum_age:
            raise ValueError("Failed or stale report")
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError(
            "Pi-hole certificate status is missing, failed or stale"
        ) from error


def wait_healthy(ca: Path, certificate: bytes) -> None:
    deadline = time.monotonic() + 45
    while True:
        try:
            healthy(ca, certificate, "127.0.0.1")
            return
        except (OSError, ValueError, http.client.HTTPException):
            if time.monotonic() >= deadline:
                raise
            time.sleep(1)


def renew(ca: Path) -> None:
    certificate = download(ca)
    if TARGET.is_symlink() or not TARGET.is_file():
        raise ValueError("Expected a regular Pi-hole PEM file")
    current = TARGET.read_bytes()
    if TARGET.stat().st_mode & 0o777 != 0o600:
        raise ValueError("Pi-hole private PEM must have mode 0600")
    key = re.search(
        rb"-----BEGIN ([A-Z ]*PRIVATE KEY)-----.*?-----END \1-----", current, re.DOTALL
    )
    if key is None:
        raise ValueError("Missing existing Pi-hole private key")
    public_key = run("openssl", "pkey", "-in", str(TARGET), "-pubout")
    verify(certificate, ca, public_key)
    try:
        healthy(ca, certificate, "127.0.0.1")
        if leaf(current) == leaf(certificate):
            print("Pi-hole certificate is current and HTTPS is healthy")
            return
    except (OSError, ValueError, http.client.HTTPException):
        pass
    metadata = TARGET.stat()
    owner = (metadata.st_uid, metadata.st_gid)
    if leaf(current) != leaf(certificate):
        atomic(PREVIOUS, current, 0o600)
    rollback = PREVIOUS.read_bytes() if PREVIOUS.exists() else current
    combined = (
        leaf(certificate) + ca.read_bytes().rstrip() + b"\n" + key.group() + b"\n"
    )
    atomic(TARGET, combined, 0o600, owner)
    try:
        run("systemctl", "restart", "pihole-FTL", timeout=180)
        wait_healthy(ca, certificate)
    except (
        OSError,
        ValueError,
        subprocess.SubprocessError,
        http.client.HTTPException,
    ) as error:
        atomic(TARGET, rollback, 0o600, owner)
        try:
            run("systemctl", "restart", "pihole-FTL", timeout=180)
            wait_healthy(ca, rollback)
        except (
            OSError,
            ValueError,
            subprocess.SubprocessError,
            http.client.HTTPException,
        ) as recovery:
            raise RuntimeError(
                "Previous PEM restored, but recovery HTTPS check failed"
            ) from recovery
        raise RuntimeError(
            "Renewal failed; restored the previous Pi-hole PEM"
        ) from error
    print(
        "Pi-hole certificate installed; all three TLS identities and login pages verified"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["publish", "renew", "check", "report"])
    parser.add_argument("--ca", type=Path, default=Path("/etc/pihole-tls/ca.crt"))
    parser.add_argument("--csr", type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    if args.command == "publish":
        if args.csr is None:
            parser.error("publish requires --csr")
        with status_file(PUBLIC.with_name("published.json")):
            publish(args.csr)
    elif args.command == "renew":
        with status_file(GUEST_STATUS):
            renew(args.ca)
    elif args.command == "report":
        report(args.ca)
    else:
        inspect(args.ca)
        check_status(args.ca, "https://192.168.2.113/pihole-tls/status.json", 7200)
        print("Pi-hole serves the current published certificate; HTTPS is healthy")


if __name__ == "__main__":
    try:
        main()
    except (
        OSError,
        ValueError,
        RuntimeError,
        subprocess.SubprocessError,
        http.client.HTTPException,
    ) as error:
        print(f"pihole-tls: {error}", file=sys.stderr)
        sys.exit(1)
