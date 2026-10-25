#!/usr/bin/env python3
"""Boot the deployable image with isolated networking and replace its root disk."""

import base64
import contextlib
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

IMAGE = Path(sys.argv[1]).resolve()


def execute(args: list, *, data: bytes | None = None) -> bytes:
    result = subprocess.run(args, input=data, capture_output=True, check=False)  # noqa: S603 -- Only disposable local fixtures are used.
    if result.returncode:
        raise RuntimeError(
            f"Image test command failed: {args[0]}: {result.stderr.decode(errors='replace')[-1500:]}"
        )
    return result.stdout


def agent_request(agent: Path, command: dict) -> dict:
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(10)
        connection.connect(str(agent))
        connection.sendall(json.dumps(command).encode() + b"\n")
        with connection.makefile("rb") as stream:
            response = json.loads(stream.readline())
        if "error" in response:
            raise RuntimeError("Guest agent command failed")
        return response["return"]


def guest(agent: Path, command: str, *, data: bytes | None = None) -> bytes:
    args = {
        "path": "/run/current-system/sw/bin/bash",
        "arg": ["-c", f"export PATH=/run/current-system/sw/bin:$PATH; {command}"],
        "capture-output": True,
    }
    if data:
        args["input-data"] = base64.b64encode(data).decode()
    pid = agent_request(agent, {"execute": "guest-exec", "arguments": args})["pid"]
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        status = agent_request(
            agent, {"execute": "guest-exec-status", "arguments": {"pid": pid}}
        )
        if status["exited"]:
            if status.get("exitcode") != 0:
                raise RuntimeError(
                    f"Guest command failed: {base64.b64decode(status.get('err-data', '')).decode(errors='replace')[-1200:]}"
                )
            return base64.b64decode(status.get("out-data", ""))
        time.sleep(0.2)
    raise RuntimeError("Guest command timed out")


def boot(
    directory: Path, data: Path, label: str
) -> tuple[subprocess.Popen, Path, Path]:
    root = directory / f"{label}.qcow2"
    execute(
        [
            "qemu-img",
            "create",
            "-q",
            "-f",
            "qcow2",
            "-F",
            "qcow2",
            "-b",
            str(IMAGE),
            str(root),
        ]
    )
    log = directory / f"{label}.log"
    agent = directory / f"{label}.sock"
    args = [
        "qemu-system-x86_64",
        "-accel",
        "kvm" if os.access("/dev/kvm", os.R_OK | os.W_OK) else "tcg",
        "-smp",
        "2",
        "-m",
        "2048",
        "-display",
        "none",
        "-serial",
        f"file:{log}",
        "-drive",
        f"file={root},format=qcow2,if=none,id=root",
        "-device",
        "virtio-blk-pci,drive=root,serial=openbao-root",
        "-drive",
        f"file={data},format=raw,if=none,id=data",
        "-device",
        "virtio-blk-pci,drive=data,serial=openbao-state",
        "-netdev",
        "user,id=net0,net=192.168.2.0/24,host=192.168.2.1,restrict=on",
        "-device",
        "virtio-net-pci,netdev=net0,addr=0x12",
        "-device",
        "virtio-serial-pci",
        "-chardev",
        f"socket,path={agent},server=on,wait=off,id=qga0",
        "-device",
        "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0",
    ]
    process = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)  # noqa: S603 -- Isolated disposable QEMU guest.
    return process, log, agent


def wait(process: subprocess.Popen, log: Path, agent: Path, command: str) -> bytes:
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"QEMU exited: {process.stderr.read().decode()}")
        try:
            return guest(agent, command)
        except (RuntimeError, OSError):
            time.sleep(2)
    raise RuntimeError(f"Guest did not become ready: {log.read_text()[-5000:]}")


def stop(process: subprocess.Popen, agent: Path) -> None:
    if process.poll() is None:
        try:
            # guest-shutdown intentionally has no response; do not poll a dying agent.
            with socket.socket(socket.AF_UNIX) as connection:
                connection.connect(str(agent))
                connection.sendall(
                    b'{"execute":"guest-shutdown","arguments":{"mode":"powerdown"}}\n'
                )
            process.wait(timeout=40)
        except (RuntimeError, OSError, subprocess.TimeoutExpired):
            process.terminate()
            process.wait(timeout=20)
    process.stderr.close()


def main(directory: Path) -> None:
    data = directory / "state.raw"
    execute(["qemu-img", "create", "-q", "-f", "raw", str(data), "64M"])
    identity = directory / "recovery.agekey"
    execute(["age-keygen", "-o", str(identity)])
    recipient = execute(["age-keygen", "-y", str(identity)])
    execute(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(directory / "ca.key"),
            "-out",
            str(directory / "ca.crt"),
            "-days",
            "2",
            "-subj",
            "/CN=Image test CA",
            "-addext",
            "basicConstraints=critical,CA:TRUE",
            "-addext",
            "keyUsage=critical,keyCertSign,cRLSign",
        ]
    )
    extensions = directory / "extensions"
    extensions.write_text(
        "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:openbao.powerlan.empire,DNS:secrets.powerlan.empire,IP:192.168.2.112\n"
    )
    original = None
    for label in ["first", "replacement"]:
        print(
            f"Booting {label} root disk with the same persistent data disk", flush=True
        )
        process, log, agent = boot(directory, data, label)
        try:
            wait(
                process,
                log,
                agent,
                "systemctl is-active --quiet openbao && mountpoint -q /srv/openbao",
            )
            if label == "first":
                guest(
                    agent,
                    "install -m 0600 /dev/stdin /srv/openbao/ops/recipient",
                    data=recipient,
                )
                guest(
                    agent,
                    "openbao-ops init --recipient-file /srv/openbao/ops/recipient",
                )
                (directory / "request.csr").write_bytes(guest(agent, "openbao-ops csr"))
                certificate = execute(
                    [
                        "openssl",
                        "x509",
                        "-req",
                        "-in",
                        str(directory / "request.csr"),
                        "-CA",
                        str(directory / "ca.crt"),
                        "-CAkey",
                        str(directory / "ca.key"),
                        "-set_serial",
                        "1",
                        "-days",
                        "2",
                        "-extfile",
                        str(extensions),
                    ]
                )
                guest(
                    agent,
                    "install -m 0644 /dev/stdin /srv/openbao/tls/server.crt",
                    data=certificate,
                )
                guest(
                    agent,
                    "install -m 0644 /dev/stdin /srv/openbao/tls/test-ca.crt",
                    data=(directory / "ca.crt").read_bytes(),
                )
                guest(agent, "systemctl restart caddy")
                original = guest(agent, "sha256sum /srv/openbao/seal/key")
            wait(
                process,
                log,
                agent,
                "curl --fail --silent --show-error http://127.0.0.1:8200/v1/sys/health >/dev/null",
            )
            status = json.loads(
                wait(
                    process,
                    log,
                    agent,
                    "curl --fail --silent --show-error --cacert /srv/openbao/tls/test-ca.crt --resolve openbao.powerlan.empire:443:127.0.0.1 https://openbao.powerlan.empire/v1/sys/health",
                )
            )
            assert status["initialized"] and not status["sealed"]
            assert guest(agent, "sha256sum /srv/openbao/seal/key") == original
            guest(
                agent,
                "test -s /srv/openbao/audit/audit.json && test -s /srv/openbao/ops/recovery.age",
            )
        except BaseException:
            with contextlib.suppress(OSError, RuntimeError):
                print(
                    guest(
                        agent,
                        "systemctl status --no-pager openbao caddy openbao-prepare openbao-data-init srv-openbao.mount; journalctl -b -u caddy -u openbao -u openbao-prepare -u openbao-data-init --no-pager -n 50; true",
                    ).decode()[-8000:],
                    file=sys.stderr,
                )
            print(log.read_text()[-6000:], file=sys.stderr)
            raise
        finally:
            stop(process, agent)
    print(
        "PASS: actual NixOS image, mounted state, HTTPS, automatic unseal and replacement root disk"
    )


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="openbao-image-") as temporary:
        main(Path(temporary))
