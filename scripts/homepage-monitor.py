#!/usr/bin/env python3
"""Publish bounded health summaries and load Homepage's own OpenBao secrets."""

import argparse
import concurrent.futures
import contextlib
import datetime as dt
import http.server
import json
import math
import re
import socket
import ssl
import sys
import time
from pathlib import Path

from openbao import Bao, atomic, login, private_json, run

STATE = Path("/var/lib/homepage-monitor")
RUNTIME = Path("/run/homepage-monitor")
SERVICES = ("forgejo-reader", "proxmox-reader")
SITES = {
    "home": "home.powerlan.empire",
    "proxmox": "proxmox.powerlan.empire",
    "pihole": "pihole.powerlan.empire",
    "freeipa": "ldap.powerlan.empire",
    "forgejo": "forgejo.powerlan.empire",
    "openbao": "openbao.powerlan.empire",
    "homeassistant": "homeassistant.powerlan.empire",
    "certs": "certs.powerlan.empire",
    "k3s-poc": "poc.apps.powerlan.empire",
    "ctb": "ctb.apps.powerlan.empire",
    "huishoudboekje": "huishoudboekje.apps.powerlan.empire",
    "recepten": "recepten.apps.powerlan.empire",
}


def fresh(value: object, maximum: int, now: float) -> bool:
    return (
        type(value) in (int, float)
        and math.isfinite(value)
        and -30 <= now - value <= maximum
    )


def certificate(item: tuple[str, str]) -> tuple[str, dict]:
    name, host = item
    try:
        with (
            socket.create_connection((host, 443), timeout=5) as raw,
            ssl.create_default_context().wrap_socket(raw, server_hostname=host) as conn,
        ):
            cert = conn.getpeercert()
        expires = ssl.cert_time_to_seconds(cert["notAfter"])
        days = math.floor((expires - time.time()) / 86400)
        return name, {"status": "OK" if days >= 30 else "Vernieuwen", "days": days}
    except (OSError, ValueError):
        return name, {"status": "Fout", "days": "?"}


def environment(proxmox: dict, pihole: dict) -> bytes:
    values = {
        "HOMEPAGE_VAR_PROXMOX_USER": proxmox["username"],
        "HOMEPAGE_VAR_PROXMOX_TOKEN": proxmox["password"],
        "HOMEPAGE_VAR_PIHOLE_KEY": pihole["password"],
    }
    if values["HOMEPAGE_VAR_PROXMOX_USER"] != "homepage@pve!dashboard":
        raise ValueError("Unexpected Proxmox monitoring identity")
    if not all(
        isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9@!_+=./:-]{8,256}", value)
        for value in values.values()
    ):
        raise ValueError("Unsafe or empty Homepage credential")
    return "".join(f"{name}={value}\n" for name, value in values.items()).encode()


def rotation(client: Bao, now: float) -> tuple[dict, dict]:
    confirmations, rotations = [], []
    for service in SERVICES:
        status = client.request(f"status/data/{service}")["data"]["data"]
        role = client.request(f"ldap/static-role/{service}")["data"]
        confirmations.append(status["applied_at"])
        stamp = role.get("last_vault_rotation") or role.get("last_rotation")
        parsed = dt.datetime.fromisoformat(stamp)
        if parsed.tzinfo is None:
            raise ValueError("Rotation time must include its timezone")
        rotations.append(parsed.timestamp())
    ldap = {
        "status": "OK" if all(fresh(t, 300, now) for t in confirmations) else "Fout"
    }
    rotate = {
        "status": "OK" if all(fresh(t, 90000, now) for t in rotations) else "Fout"
    }
    for result, times in ((ldap, confirmations), (rotate, rotations)):
        result["last"] = dt.datetime.fromtimestamp(min(times), dt.UTC).isoformat()
    return ldap, rotate


def backup(data: dict, now: float) -> dict:
    stamp, last = data.get("checked_at"), data.get("last_success")
    healthy = (
        fresh(stamp, 900, now)
        and fresh(last, 7200, now)
        and data.get("result") == "success"
    )
    return {
        "status": "OK" if healthy else "Fout",
        "last": dt.datetime.fromtimestamp(last, dt.UTC).isoformat()
        if type(last) in (int, float) and math.isfinite(last) and 0 < last <= now + 30
        else None,
    }


def collect() -> None:
    now = time.time()
    RUNTIME.mkdir(mode=0o755, exist_ok=True)
    result = {
        "checked_at": now,
        "ldap": {"status": "Onbekend", "last": None},
        "rotation": {"status": "Onbekend", "last": None},
        "credentials": {"status": "Fout"},
    }
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        result["certificates"] = dict(pool.map(certificate, SITES.items()))
    try:
        answer = (
            run(
                [
                    "dig",
                    "+time=2",
                    "+tries=1",
                    "+short",
                    "@192.168.2.102",
                    "home.powerlan.empire",
                    "A",
                ]
            )
            .decode()
            .splitlines()
        )
        result["dns"] = {"status": "OK" if answer == ["192.168.2.111"] else "Fout"}
    except (OSError, RuntimeError):
        result["dns"] = {"status": "Fout"}
    try:
        client = Bao("https://192.168.2.112")
        login(client, private_json(STATE / "approle.json"))
        try:
            try:
                proxmox = client.request("services/data/homepage/proxmox")["data"][
                    "data"
                ]
                pihole = client.request("services/data/homepage/pihole")["data"]["data"]
                content = environment(proxmox, pihole)
                target = RUNTIME / "credentials.env"
                if not target.exists() or target.read_bytes() != content:
                    atomic(target, content)
                    run(
                        [
                            "systemctl",
                            "try-restart",
                            "--no-block",
                            "homepage-dashboard.service",
                        ]
                    )
                result["credentials"]["status"] = "OK"
            except (
                OSError,
                ValueError,
                KeyError,
                RuntimeError,
            ):
                print(
                    "Homepage credentials unavailable; previous environment retained",
                    file=sys.stderr,
                )
            result["ldap"], result["rotation"] = rotation(client, now)
        finally:
            client.request("auth/token/revoke-self", {})
    except (OSError, ValueError, KeyError, TypeError, RuntimeError):
        print(
            "OpenBao monitoring unavailable; no secret response logged", file=sys.stderr
        )
    try:
        result["backup"] = backup(private_json(STATE / "offhost-backup.json"), now)
    except (OSError, ValueError, TypeError, OverflowError):
        result["backup"] = {"status": "Onbekend", "last": None}
    atomic(RUNTIME / "status.json", json.dumps(result).encode(), mode=0o644)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path != "/status.json":
            self.send_error(404)
            return
        try:
            content = (RUNTIME / "status.json").read_bytes()
            if not fresh(json.loads(content)["checked_at"], 180, time.time()):
                raise ValueError("Stale monitoring")
        except (OSError, ValueError, KeyError, TypeError):
            self.send_error(503, "Monitoring unavailable or stale")
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def log_message(self, *_: object) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["collect", "serve", "receive-backup"])
    args = parser.parse_args()
    if args.command == "serve":
        http.server.ThreadingHTTPServer(("127.0.0.1", 3001), Handler).serve_forever()
    elif args.command == "receive-backup":
        content = sys.stdin.buffer.read(4097)
        if len(content) > 4096:
            raise ValueError("Backup report exceeds limit")
        data = json.loads(content)
        if set(data) != {"checked_at", "last_success", "result"} or not fresh(
            data["checked_at"], 60, time.time()
        ):
            raise ValueError("Unexpected backup report")
        backup(data, time.time())
        STATE.mkdir(mode=0o700, exist_ok=True)
        atomic(STATE / "offhost-backup.json", json.dumps(data).encode())
    else:
        collect()


if __name__ == "__main__":
    with contextlib.suppress(KeyboardInterrupt):
        main()
