#!/usr/bin/env python3
"""Exercise real Raft, auto-unseal, LDAP rotation, AppRole isolation and backups."""

import contextlib
import importlib.util
import io
import json
import os
import secrets
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
from collections.abc import Callable, Iterator
from pathlib import Path
from unittest.mock import patch

SCRIPT = (
    Path(sys.argv[1])
    if len(sys.argv) > 1
    else Path(__file__).resolve().parents[1] / "scripts/openbao.py"
)
SPEC = importlib.util.spec_from_file_location("openbao", SCRIPT)
ops = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ops)


def execute(args: list, *, data: bytes | None = None) -> bytes:
    result = subprocess.run(  # noqa: S603 -- Integration fixtures supply the argument arrays.
        [str(value) for value in args], input=data, capture_output=True, check=False
    )
    if result.returncode:
        raise RuntimeError(
            f"Test command failed: {args[0]}: {result.stderr.decode(errors='replace')[:1000]}"
        )
    return result.stdout


def wait(predicate: Callable[[], bool], process: subprocess.Popen, log: Path) -> None:
    end = time.monotonic() + 40
    while time.monotonic() < end:
        try:
            if predicate():
                return
        except (OSError, ValueError, RuntimeError):
            pass
        if process.poll() is not None:
            raise RuntimeError(f"Test server exited: {log.read_text()[-3000:]}")
        time.sleep(0.2)
    raise RuntimeError(f"Test server did not become ready: {log.read_text()[-3000:]}")


@contextlib.contextmanager
def server(args: list, log: Path) -> Iterator[subprocess.Popen]:
    with log.open("wb") as stream:
        process = subprocess.Popen(args, stdout=stream, stderr=subprocess.STDOUT)  # noqa: S603 -- Disposable local fixture servers only.
        try:
            yield process
        except BaseException:
            print(log.read_text()[-4000:], file=sys.stderr)
            raise
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def denied(client: ops.Bao, path: str) -> None:
    try:
        client.request(path)
    except RuntimeError as error:
        if "HTTP 403" not in str(error):
            raise AssertionError(str(error)) from error
    else:
        raise AssertionError(f"Unexpectedly allowed: {path}")


# shortcut: one ordered integration scenario, split when scenarios need independent setup.
def main(directory: Path) -> None:  # noqa: C901, PLR0912, PLR0915
    os.umask(0o077)
    ca = directory / "ca.crt"
    key = directory / "ca.key"
    execute(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            key,
            "-out",
            ca,
            "-days",
            "2",
            "-subj",
            "/CN=localhost",
            "-addext",
            "subjectAltName=IP:127.0.0.1,DNS:localhost",
        ]
    )
    ops.CA = str(ca)
    with socket.socket() as port_socket:
        port_socket.bind(("127.0.0.1", 0))
        port = port_socket.getsockname()[1]
    ldap_url = f"ldaps://127.0.0.1:{port}"
    ops.LDAP_URL = ldap_url
    schema = Path(shutil.which("slapd")).resolve().parents[1] / "etc/schema"
    database = directory / "ldap"
    database.mkdir()
    admin_password = secrets.token_urlsafe(24)
    manager_password = secrets.token_urlsafe(32)
    dn = f"uid=openbao-rotator,{ops.ACCOUNTS}"
    slapd = directory / "slapd.conf"
    slapd.write_text(f'''include {schema}/core.schema
include {schema}/cosine.schema
include {schema}/inetorgperson.schema
pidfile {directory}/slapd.pid
argsfile {directory}/slapd.args
TLSCertificateFile {ca}
TLSCertificateKeyFile {key}
TLSCACertificateFile {ca}
database mdb
maxsize 1073741824
suffix "{ops.BASE}"
rootdn "cn=admin,{ops.BASE}"
rootpw {admin_password}
directory {database}
access to dn.regex="^uid=(openbao-rotator|forgejo-reader|proxmox-reader),cn=sysaccounts,cn=etc,{ops.BASE}$" attrs=userPassword
  by dn.exact="{dn}" write
  by anonymous auth
  by self write
  by * none
access to attrs=userPassword
  by anonymous auth
  by self write
  by * none
access to * by * read
''')
    env = os.environ | {"LDAPTLS_CACERT": str(ca), "LDAPTLS_REQCERT": "demand"}
    os.environ.update(env)
    admin_file = directory / "ldap-admin-password"
    admin_file.write_text(admin_password)
    ldif = f"""dn: {ops.BASE}
objectClass: domain
dc: powerlan

dn: cn=etc,{ops.BASE}
objectClass: organizationalRole
cn: etc

dn: {ops.ACCOUNTS}
objectClass: organizationalRole
cn: sysaccounts
"""
    for name in ["openbao-rotator", *ops.SERVICES]:
        password = (
            manager_password if name == "openbao-rotator" else secrets.token_urlsafe(32)
        )
        ldif += f"\ndn: uid={name},{ops.ACCOUNTS}\nobjectClass: account\nobjectClass: simpleSecurityObject\nuid: {name}\nuserPassword: {password}\n"
    ldif += f"\ndn: uid=unrelated,{ops.BASE}\nobjectClass: account\nobjectClass: simpleSecurityObject\nuid: unrelated\nuserPassword: {secrets.token_urlsafe(32)}\n"
    ldap_log = directory / "ldap.log"
    with server(
        ["slapd", "-f", str(slapd), "-h", ldap_url, "-d", "0"], ldap_log
    ) as ldap:
        wait(
            lambda: (
                subprocess.run(  # noqa: S603 -- Synthetic LDAP fixture credentials only.
                    [
                        shutil.which("ldapwhoami"),
                        "-x",
                        "-H",
                        ldap_url,
                        "-D",
                        f"cn=admin,{ops.BASE}",
                        "-y",
                        str(admin_file),
                    ],
                    capture_output=True,
                    check=False,
                ).returncode
                == 0
            ),
            ldap,
            ldap_log,
        )
        execute(
            [
                "ldapadd",
                "-x",
                "-H",
                ldap_url,
                "-D",
                f"cn=admin,{ops.BASE}",
                "-y",
                admin_file,
            ],
            data=ldif.encode(),
        )
        root = directory / "vault"
        for name in ["raft", "seal", "audit", "ops", "backups", "tls"]:
            (root / name).mkdir(parents=True)
        (root / "seal/key").write_bytes(secrets.token_bytes(32))
        shutil.copyfile(ca, root / "tls/server.crt")
        shutil.copyfile(key, root / "tls/server.key")
        config = directory / "bao.json"
        config.write_text(
            json.dumps(
                {
                    "disable_mlock": True,
                    "audit": [
                        {
                            "file": {
                                "local": {
                                    "description": "Test audit",
                                    "options": {
                                        "file_path": str(root / "audit/audit.json"),
                                        "log_raw": "false",
                                    },
                                }
                            }
                        }
                    ],
                    "api_addr": "http://127.0.0.1:8200",
                    "cluster_addr": "http://127.0.0.1:8201",
                    "listener": {
                        "tcp": {"address": "127.0.0.1:8200", "tls_disable": True}
                    },
                    "storage": {
                        "raft": {"path": str(root / "raft"), "node_id": "openbao-01"}
                    },
                    "seal": {
                        "static": {
                            "current_key_id": "local-1",
                            "current_key": f"file://{root}/seal/key",
                        }
                    },
                }
            )
        )
        identity = directory / "recovery.agekey"
        execute(["age-keygen", "-o", identity])
        recipient = directory / "recipient"
        recipient.write_bytes(execute(["age-keygen", "-y", identity]))
        manager_file = directory / "manager-password"
        manager_file.write_text(manager_password)
        log = directory / "bao.log"
        states = {}
        initial_passwords = {}
        with server(["bao", "server", "-config", str(config)], log) as bao:
            client = ops.Bao("http://127.0.0.1:8200")
            wait(lambda: client.request("sys/init") is not None, bao, log)
            ops.initialize(root, recipient)
            # Resume an interrupted export without generating another seal key or init response.
            original_key = (root / "seal/key").read_bytes()
            (root / "ops/recovery.age").unlink()
            ops.initialize(root, recipient)
            assert (root / "seal/key").read_bytes() == original_key
            wait(lambda: client.request("sys/health")["sealed"] is False, bao, log)
            ops.configure(root, manager_file)
            client.token = ops.private_json(root / "ops/pending-init.json")[
                "root_token"
            ]
            # The engine rotates its own delegated account, not the directory administrator.
            try:
                ops.ldap_check(dn, manager_file)
            except RuntimeError:
                pass
            else:
                raise AssertionError("LDAP manager password was not rotated")
            for service in ops.SERVICES:
                credential = ops.role(
                    client,
                    service,
                    f'path "ldap/static-cred/{service}" {{ capabilities = ["read"] }}\npath "status/data/{service}" {{ capabilities = ["create", "update"] }}',
                    ["127.0.0.1/32"],
                )
                state = directory / service
                state.mkdir()
                ops.atomic(state / "credentials.json", json.dumps(credential).encode())
                consumer_config = directory / f"{service}.json"
                consumer_config.write_text(
                    json.dumps(
                        {
                            "service": service,
                            "address": client.address,
                            "ca": str(ca),
                            "ldap_url": ldap_url,
                            "ldap_ca": str(ca),
                        }
                    )
                )
                states[service] = (consumer_config, state)
                ops.activate(root, service)
                password = client.request(f"ldap/static-cred/{service}")["data"][
                    "password"
                ]
                initial_passwords[service] = password
                service_client = ops.Bao(client.address, ca=str(ca))
                ops.login(service_client, credential)
                other = next(name for name in ops.SERVICES if name != service)
                denied(service_client, f"ldap/static-cred/{other}")
                denied(service_client, "sys/storage/raft/snapshot")
                denied(service_client, "ldap/config")
                with patch.object(ops, "apply_password") as apply:
                    ops.consume(consumer_config, state)
                    apply.assert_called_once()
                with patch.object(ops, "apply_password") as apply:
                    ops.consume(consumer_config, state)
                    apply.assert_not_called()
            ops.snapshot(root)
            recovered = execute(
                ["age", "-d", "-i", identity, root / "backups/latest.age"]
            )
            with tarfile.open(fileobj=io.BytesIO(recovered)) as tar:
                assert set(tar.getnames()) == {
                    "raft.snap",
                    "seal.key",
                    "recovery.age",
                    "backup-credentials.json",
                    "recipient",
                    "server.crt",
                    "server.key",
                }
                assert tar.extractfile("seal.key").read() == original_key
                assert tar.extractfile("server.crt").read() == ca.read_bytes()
                assert tar.extractfile("server.key").read() == key.read_bytes()
                saved_snapshot = tar.extractfile("raft.snap").read()
            for service in ops.SERVICES:
                client.request(f"ldap/rotate-role/{service}", {})
                current = client.request(f"ldap/static-cred/{service}")["data"][
                    "password"
                ]
                assert current != initial_passwords[service]
                consumer_config, state = states[service]
                before = (state / "applied.json").read_bytes()
                with patch.object(
                    ops,
                    "apply_password",
                    side_effect=RuntimeError("test application failure"),
                ):
                    try:
                        ops.consume(consumer_config, state)
                    except RuntimeError:
                        pass
                    else:
                        raise AssertionError("A failed application update was accepted")
                assert (state / "applied.json").read_bytes() == before
                with patch.object(ops, "apply_password"):
                    ops.consume(consumer_config, state)
            # Restore while networking is restricted to this test's disposable LDAP server.
            client.request("sys/storage/raft/snapshot", saved_snapshot, method="POST")
            wait(lambda: client.request("sys/health")["sealed"] is False, bao, log)
            for service in ops.SERVICES:
                stale = client.request(f"ldap/static-cred/{service}")["data"][
                    "password"
                ]
                assert stale == initial_passwords[service]
                consumer_config, state = states[service]
                with patch.object(ops, "apply_password") as apply:
                    try:
                        ops.consume(consumer_config, state)
                    except RuntimeError:
                        pass
                    else:
                        raise AssertionError(
                            "A restored stale password was accepted by LDAP"
                        )
                    apply.assert_not_called()
                client.request(f"ldap/rotate-role/{service}", {})
                with patch.object(ops, "apply_password"):
                    ops.consume(consumer_config, state)
            ops.finalize(root)
            denied(client, "sys/mounts")
            assert not (root / "ops/pending-init.json").exists()
            ops.snapshot(root)
        with server(["bao", "server", "-config", str(config)], log) as restarted:
            client = ops.Bao("http://127.0.0.1:8200")
            wait(
                lambda: client.request("sys/health")["sealed"] is False, restarted, log
            )
            for consumer_config, state in states.values():
                with patch.object(ops, "apply_password"):
                    ops.consume(consumer_config, state)
            ops.snapshot(root)
        try:
            ops.Bao("http://192.0.2.1:8200")
        except ValueError:
            pass
        else:
            raise AssertionError("Insecure remote HTTP was accepted")
    print(
        "PASS: real LDAP rotation, denied cross-service access, retry, encrypted snapshot, stale restore recovery, root revocation and automatic unseal"
    )


if __name__ == "__main__":
    with (
        tempfile.TemporaryDirectory(prefix="openbao-integration-") as temporary,
        patch.object(ops, "verify_application"),
    ):
        main(Path(temporary))
