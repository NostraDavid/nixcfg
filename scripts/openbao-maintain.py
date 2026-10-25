#!/usr/bin/env python3
"""Keep encrypted OpenBao recovery copies on the management workstation."""

import argparse
import datetime as dt
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

VAULT = "david@192.168.2.112"
PROXY = "david@192.168.2.111"
SSH = [
    shutil.which("ssh") or "/usr/bin/ssh",
    "-F",
    "/dev/null",
    "-o",
    "BatchMode=yes",
    "-o",
    "StrictHostKeyChecking=yes",
    "-o",
    "ConnectTimeout=10",
]
STATE = Path.home() / ".local/state/nixcfg/openbao"


def remote(target: str, command: str, data: bytes | None = None) -> bytes:
    result = subprocess.run(  # noqa: S603 -- Targets and remote operations are fixed in this module.
        [*SSH, target, command],
        input=data,
        capture_output=True,
        check=False,
        timeout=180,
    )
    if result.returncode:
        raise RuntimeError(
            f"OpenBao maintenance failed on {target}; check SSH and the remote service"
        )
    return result.stdout


def setup(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    identity = directory / "recovery.agekey"
    if not identity.exists():
        subprocess.run(  # noqa: S603 -- Only an operator-selected output path varies.
            [shutil.which("age-keygen") or "/usr/bin/age-keygen", "-o", str(identity)],
            check=True,
            capture_output=True,
        )
    recipient = subprocess.run(  # noqa: S603 -- No shell is used.
        [shutil.which("age-keygen") or "/usr/bin/age-keygen", "-y", str(identity)],
        check=True,
        capture_output=True,
    ).stdout
    (directory / "recipient").write_bytes(recipient)
    print(
        f"Public recipient: {directory / 'recipient'}; keep the private recovery.agekey outside Proxmox"
    )


def backup(directory: Path) -> None:
    content = remote(VAULT, "sudo -n openbao-ops export")
    if not content.startswith(b"age-encryption.org/v1\n"):
        raise ValueError("Refusing an unencrypted or empty vault backup")
    backups = directory / "backups"
    backups.mkdir(mode=0o700, parents=True, exist_ok=True)
    timestamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    destination = backups / f"{timestamp}.tar.age"
    with tempfile.NamedTemporaryFile(dir=backups, delete=False) as temporary:
        staging = Path(temporary.name)
        temporary.write(content)
        temporary.flush()
        os.fsync(temporary.fileno())
    staging.replace(destination)
    # A successful transfer alone does not prove that the independent key works.
    result = subprocess.run(  # noqa: S603 -- Both file paths are inside the private recovery directory.
        [
            shutil.which("age") or "/usr/bin/age",
            "-d",
            "-i",
            str(directory / "recovery.agekey"),
            str(destination),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(
            "The off-host backup cannot be decrypted with the workstation recovery key"
        )
    for previous in backups.glob("*.tar.age"):
        if previous.stat().st_mtime < time.time() - 7 * 86400:
            previous.unlink()
    print(f"Verified encrypted off-host backup: {destination}")


def tls() -> None:
    csr = remote(VAULT, "sudo -n openbao-ops csr")
    # Only the public CSR and certificate cross hosts; the trusted CA key stays on the proxy.
    body = """set -euo pipefail
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/request.csr"
cat > "$work/extensions" <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:openbao.powerlan.empire,DNS:secrets.powerlan.empire,IP:192.168.2.112
EOF
openssl x509 -req -in "$work/request.csr" -CA /srv/proxy/caddy/.local/share/caddy/pki/authorities/local/root.crt -CAkey /srv/proxy/caddy/.local/share/caddy/pki/authorities/local/root.key -set_serial "0x$(openssl rand -hex 16)" -days 90 -sha256 -extfile "$work/extensions" 2>/dev/null
"""
    sign = "sudo -n bash -c " + shlex.quote(body)
    certificate = remote(PROXY, sign, csr)
    remote(VAULT, "sudo -n openbao-ops install-certificate", certificate)
    print("Vault TLS certificate renewed using the existing trusted internal CA")


def check(directory: Path) -> None:
    remote(VAULT, "sudo -n openbao-ops check")
    backups = list((directory / "backups").glob("*.tar.age"))
    if (
        not backups
        or time.time() - max(path.stat().st_mtime for path in backups) > 7200
    ):
        raise RuntimeError(
            "No verified off-host vault backup exists from the last two hours"
        )
    print("ok")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["setup", "backup", "tls", "check"])
    parser.add_argument("--directory", type=Path, default=STATE)
    args = parser.parse_args()
    os.umask(0o077)
    if args.command == "setup":
        setup(args.directory)
    elif args.command == "backup":
        backup(args.directory)
    elif args.command == "tls":
        tls()
    else:
        check(args.directory)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"openbao-maintain: {error}", file=sys.stderr)
        sys.exit(1)
