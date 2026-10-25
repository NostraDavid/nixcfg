#!/usr/bin/env python3
"""Operate the local vault and reconcile its two LDAP password consumers."""

import argparse
import datetime as dt
import hashlib
import io
import json
import os
import pwd
import secrets
import ssl
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

BASE = "dc=powerlan,dc=empire"
ACCOUNTS = f"cn=sysaccounts,cn=etc,{BASE}"
LDAP_URL = "ldaps://ldap.powerlan.empire"
SERVICES = {"forgejo-reader": "192.168.2.110/32", "proxmox-reader": "192.168.2.100/32"}
CA = "/etc/ssl/certs/ca-certificates.crt"
ADMIN_POLICY = 'path "*" { capabilities = ["create", "read", "update", "delete", "list", "sudo", "patch"] }'
SELF_POLICY = '\npath "auth/token/revoke-self" { capabilities = ["update"] }\n'


class MissingError(RuntimeError):
    """An optional OpenBao endpoint does not exist."""


class Bao:
    def __init__(self, address: str, token: str = "", ca: str | None = None) -> None:
        parsed = urllib.parse.urlparse(address)
        if parsed.scheme != "https" and not (
            parsed.scheme == "http" and parsed.hostname in {"127.0.0.1", "::1"}
        ):
            raise ValueError(
                "OpenBao requires HTTPS outside its local management listener"
            )
        self.address = address.rstrip("/")
        self.token = token
        self.context = ssl.create_default_context(cafile=ca or CA)

    def request(
        self,
        path: str,
        data: dict | bytes | None = None,
        *,
        method: str = "",
        binary: bool = False,
    ) -> dict | bytes:
        request = urllib.request.Request(  # noqa: S310 -- The constructor permits HTTPS and loopback HTTP only.
            f"{self.address}/v1/{path}",
            data=data
            if isinstance(data, bytes)
            else (None if data is None else json.dumps(data).encode()),
            headers={"X-Vault-Token": self.token, "Content-Type": "application/json"},
            method=method or ("GET" if data is None else "POST"),
        )
        try:
            with urllib.request.urlopen(  # noqa: S310 -- The address is validated in the constructor.
                request, context=self.context, timeout=120
            ) as response:
                content = response.read()
        except urllib.error.HTTPError as error:
            if error.code == 404:
                raise MissingError(
                    f"OpenBao endpoint is not configured: {path}"
                ) from None
            # API error bodies can contain credentials or request data.
            raise RuntimeError(f"OpenBao {path}: HTTP {error.code}") from None
        except urllib.error.URLError:
            raise RuntimeError(
                "OpenBao connection failed; check the service and its TLS certificate"
            ) from None
        if binary:
            return content
        result = json.loads(content) if content else {}
        if not isinstance(result, dict):
            raise TypeError("OpenBao returned a non-object response")
        return result

    def optional(self, path: str) -> dict | None:
        try:
            return self.request(path)
        except MissingError:
            return None


def private_bytes(path: Path) -> bytes:
    mode = path.lstat()
    if (
        not stat.S_ISREG(mode.st_mode)
        or mode.st_mode & 0o077
        or mode.st_uid != os.geteuid()
    ):
        raise ValueError(f"Expected an owner-only regular credential file: {path}")
    return path.read_bytes()


def private_json(path: Path) -> dict:
    value = json.loads(private_bytes(path))
    if not isinstance(value, dict):
        raise TypeError(f"Expected a JSON object: {path}")
    return value


def atomic(
    path: Path, value: bytes, *, mode: int = 0o600, owner: str | None = None
) -> None:
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            os.fchmod(stream.fileno(), mode)
            if owner:
                account = pwd.getpwnam(owner)
                os.fchown(stream.fileno(), account.pw_uid, account.pw_gid)
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        Path(temporary).replace(path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        Path(temporary).unlink(missing_ok=True)


def run(command: list, *, data: bytes | None = None, env: dict | None = None) -> bytes:
    result = subprocess.run(  # noqa: S603 -- Fixed operations pass argument arrays, never shell input.
        command, input=data, capture_output=True, check=False, timeout=120, env=env
    )
    if result.returncode:
        raise RuntimeError(
            f"Command failed: {Path(command[0]).name}; inspect the service without logging credentials"
        )
    return result.stdout


def encrypt(recipient: str, content: bytes) -> bytes:
    return run(["age", "-r", recipient], data=content)


def archive(files: dict[str, bytes]) -> bytes:
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w") as tar:
        for name, content in files.items():
            member = tarfile.TarInfo(name)
            member.size = len(content)
            member.mode = 0o600
            tar.addfile(member, io.BytesIO(content))
    return output.getvalue()


def login(client: Bao, credentials: dict) -> None:
    if not all(
        isinstance(credentials.get(key), str) and credentials[key]
        for key in ("role_id", "secret_id")
    ):
        raise ValueError("Missing AppRole credentials")
    result = client.request(
        "auth/approle/login",
        {key: credentials[key] for key in ("role_id", "secret_id")},
    )
    client.token = result["auth"]["client_token"]


def ldap_check(
    dn: str, password_file: Path, *, url: str | None = None, ca: str | None = None
) -> None:
    url = url or LDAP_URL
    if not url.startswith("ldaps://"):
        raise ValueError("LDAP password checks require LDAPS")
    env = os.environ | {"LDAPTLS_CACERT": ca or CA, "LDAPTLS_REQCERT": "demand"}
    run(["ldapwhoami", "-x", "-H", url, "-D", dn, "-y", str(password_file)], env=env)


def bootstrap_client(root: Path) -> Bao:
    token = os.environ.get("BAO_TOKEN")
    if not token:
        token = private_json(root / "ops/pending-init.json")["root_token"]
    return Bao("http://127.0.0.1:8200", token)


def initialize(root: Path, recipient_file: Path) -> None:
    client = Bao("http://127.0.0.1:8200")
    pending = root / "ops/pending-init.json"
    recipient = recipient_file.read_text().strip()
    # Validate the public recipient before the irreversible init call.
    encrypt(recipient, b"recipient-check")
    if client.request("sys/init")["initialized"]:
        if not pending.exists() and not (root / "ops/recovery.age").exists():
            raise RuntimeError(
                "Vault is initialized but recovery material is missing; restore it before continuing"
            )
        if pending.exists() and not (root / "ops/recovery.age").exists():
            initialized = private_json(pending)
            atomic(root / "ops/recipient", recipient.encode())
            recovery = archive(
                {
                    "initialization.json": json.dumps(initialized).encode(),
                    "seal.key": (root / "seal/key").read_bytes(),
                }
            )
            atomic(root / "ops/recovery.age", encrypt(recipient, recovery))
        print("OpenBao is already initialized")
        return
    if len((root / "seal/key").read_bytes()) != 32:
        raise ValueError("The original 32-byte static seal key is required")
    initialized = client.request(
        "sys/init", {"recovery_shares": 3, "recovery_threshold": 2}
    )
    initialized["rescue_password"] = secrets.token_urlsafe(48)
    atomic(pending, json.dumps(initialized).encode())
    atomic(root / "ops/recipient", recipient.encode())
    recovery = archive(
        {
            "initialization.json": json.dumps(initialized).encode(),
            "seal.key": (root / "seal/key").read_bytes(),
        }
    )
    atomic(root / "ops/recovery.age", encrypt(recipient, recovery))
    print(
        "OpenBao initialized; encrypted recovery material is in /srv/openbao/ops/recovery.age"
    )


def mount(
    client: Bao,
    path: str,
    kind: str,
    *,
    auth: bool = False,
    options: dict | None = None,
) -> None:
    endpoint = "sys/auth" if auth else "sys/mounts"
    existing = client.request(endpoint).get("data", {})
    if f"{path}/" in existing:
        if existing[f"{path}/"]["type"] != kind:
            raise ValueError(f"Unexpected existing OpenBao mount: {path}")
        return
    client.request(f"{endpoint}/{path}", {"type": kind, "options": options or {}})


def role(client: Bao, name: str, policy: str, cidrs: list[str]) -> dict:
    client.request(f"sys/policies/acl/{name}", {"policy": policy + SELF_POLICY})
    client.request(
        f"auth/approle/role/{name}",
        {
            "token_policies": [name],
            "token_no_default_policy": True,
            "token_ttl": "5m",
            "token_max_ttl": "5m",
            "secret_id_bound_cidrs": cidrs,
            "token_bound_cidrs": cidrs,
            "secret_id_num_uses": 0,
            "secret_id_ttl": 0,
        },
    )
    return {
        "role_id": client.request(f"auth/approle/role/{name}/role-id")["data"][
            "role_id"
        ],
        "secret_id": client.request(f"auth/approle/role/{name}/secret-id", {})["data"][
            "secret_id"
        ],
    }


def configure(root: Path, password_file: Path | None) -> None:
    client = bootstrap_client(root)
    mount(client, "approle", "approle", auth=True)
    mount(client, "ldap", "ldap", auth=True)
    mount(client, "userpass", "userpass", auth=True)
    mount(client, "ldap", "ldap")
    mount(client, "status", "kv", options={"version": "2"})
    if not client.request("sys/audit").get("data"):
        raise RuntimeError(
            "The declarative audit device must be enabled before configuration"
        )
    client.request("sys/policies/acl/openbao-admin", {"policy": ADMIN_POLICY})
    client.request(
        "auth/ldap/config",
        {
            "url": LDAP_URL,
            "certificate": Path(CA).read_text(),
            "insecure_tls": False,
            "userdn": f"cn=users,cn=accounts,{BASE}",
            "userattr": "uid",
            "discoverdn": False,
            "deny_null_bind": True,
            "groupdn": f"cn=groups,cn=accounts,{BASE}",
            "groupattr": "cn",
            "groupfilter": "(&(objectClass=groupOfNames)(member={{.UserDN}}))",
            "token_no_default_policy": True,
            "token_ttl": "15m",
            "token_max_ttl": "1h",
        },
    )
    client.request("auth/ldap/groups/grp-infra-admin", {"policies": ["openbao-admin"]})
    pending = root / "ops/pending-init.json"
    if pending.exists():
        rescue = private_json(pending)["rescue_password"]
        client.request(
            "auth/userpass/users/recovery-admin",
            {
                "password": rescue,
                "token_policies": ["openbao-admin"],
                "token_no_default_policy": True,
                "token_ttl": "15m",
                "token_max_ttl": "1h",
            },
        )
    policy = (
        'path "sys/storage/raft/snapshot" { capabilities = ["read", "sudo"] }\n'
        'path "status/data/*" { capabilities = ["read"] }\n'
        'path "ldap/static-role/*" { capabilities = ["read"] }'
    )
    backup = root / "ops/backup-credentials.json"
    if not backup.exists():
        atomic(
            backup,
            json.dumps(
                role(client, "openbao-backup", policy, ["127.0.0.1/32"])
            ).encode(),
        )
    if client.optional("ldap/config") is None:
        if password_file is None:
            raise ValueError("Initial LDAP setup requires --ldap-password-file")
        password = private_bytes(password_file).decode().strip()
        ldap_check(f"uid=openbao-rotator,{ACCOUNTS}", password_file)
        client.request(
            "ldap/config",
            {
                "url": LDAP_URL,
                "binddn": f"uid=openbao-rotator,{ACCOUNTS}",
                "bindpass": password,
                "schema": "openldap",
                "userdn": ACCOUNTS,
                "userattr": "uid",
                "certificate": Path(CA).read_text(),
                "insecure_tls": False,
            },
        )
        client.request("ldap/rotate-root", {})
    print(
        "Policies, human login, recovery login, LDAP engine and backup role configured"
    )


def enroll(root: Path, service: str) -> None:
    target = root / f"ops/{service}-credentials.json"
    if target.exists():
        print(f"Existing enrollment retained: {target}")
        return
    policy = f'path "ldap/static-cred/{service}" {{ capabilities = ["read"] }}\npath "status/data/{service}" {{ capabilities = ["create", "update"] }}'
    credentials = role(bootstrap_client(root), service, policy, [SERVICES[service]])
    atomic(target, json.dumps(credentials).encode())
    print(f"Enrollment created: {target}; install it on its consumer before activation")


def activate(root: Path, service: str) -> None:
    client = bootstrap_client(root)
    if client.optional(f"ldap/static-role/{service}") is None:
        client.request(
            f"ldap/static-role/{service}",
            {
                "dn": f"uid={service},{ACCOUNTS}",
                "username": service,
                "rotation_period": "24h",
            },
        )
    print(f"Daily rotation enabled for {service}")


def fingerprint(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def finalize(root: Path) -> None:
    client = bootstrap_client(root)
    for service in SERVICES:
        secret = client.request(f"ldap/static-cred/{service}")["data"]
        status = client.request(f"status/data/{service}")["data"]["data"]
        if (
            status["password_sha256"] != fingerprint(secret["password"])
            or time.time() - status["applied_at"] > 300
        ):
            raise RuntimeError(
                f"Consumer has not confirmed the current password: {service}"
            )
    if not (root / "ops/recovery.age").is_file():
        raise RuntimeError("Encrypted recovery material is missing")
    pending = root / "ops/pending-init.json"
    if pending.exists():
        initialized = private_json(pending)
        initialized.pop("root_token", None)
        atomic(
            root / "ops/recovery.age",
            encrypt(
                (root / "ops/recipient").read_text(),
                archive(
                    {
                        "initialization.json": json.dumps(initialized).encode(),
                        "seal.key": (root / "seal/key").read_bytes(),
                    }
                ),
            ),
        )
        client.request("auth/token/revoke-self", {})
        pending.unlink()
    for service in SERVICES:
        (root / f"ops/{service}-credentials.json").unlink(missing_ok=True)
    print(
        "Both consumers confirmed; initial root token revoked and enrollment copies removed"
    )


def snapshot(root: Path) -> None:
    client = Bao("http://127.0.0.1:8200")
    login(client, private_json(root / "ops/backup-credentials.json"))
    try:
        content = client.request("sys/storage/raft/snapshot", binary=True)
    finally:
        client.request("auth/token/revoke-self", {})
    content = archive(
        {
            "raft.snap": content,
            "seal.key": (root / "seal/key").read_bytes(),
            "recovery.age": (root / "ops/recovery.age").read_bytes(),
            "backup-credentials.json": (
                root / "ops/backup-credentials.json"
            ).read_bytes(),
            "recipient": (root / "ops/recipient").read_bytes(),
            "server.crt": (root / "tls/server.crt").read_bytes(),
            "server.key": (root / "tls/server.key").read_bytes(),
        }
    )
    atomic(
        root / "backups/latest.age",
        encrypt((root / "ops/recipient").read_text(), content),
    )
    print("Consistent encrypted snapshot completed")


def check(root: Path) -> None:
    client = Bao("http://127.0.0.1:8200")
    client.request("sys/health")
    login(client, private_json(root / "ops/backup-credentials.json"))
    try:
        for service in SERVICES:
            status = client.request(f"status/data/{service}")["data"]["data"]
            if time.time() - status["applied_at"] > 300:
                raise RuntimeError(
                    f"Consumer confirmation is older than five minutes: {service}"
                )
            rotation = client.request(f"ldap/static-role/{service}")["data"]
            last = rotation.get("last_vault_rotation") or rotation.get("last_rotation")
            if (
                not last
                or time.time() - dt.datetime.fromisoformat(last).timestamp() > 90000
            ):
                raise RuntimeError(f"LDAP rotation is overdue: {service}")
        if time.time() - (root / "backups/latest.age").stat().st_mtime > 7200:
            raise RuntimeError("Encrypted snapshot is older than two hours")
        run(
            [
                "openssl",
                "x509",
                "-in",
                str(root / "tls/server.crt"),
                "-noout",
                "-checkend",
                "1209600",
            ]
        )
    finally:
        client.request("auth/token/revoke-self", {})
    print("ok")


def csr(root: Path) -> None:
    key = root / "tls/server.key"
    if not key.exists():
        run(
            [
                "openssl",
                "genpkey",
                "-algorithm",
                "EC",
                "-pkeyopt",
                "ec_paramgen_curve:P-256",
                "-out",
                str(key),
            ]
        )
        key.chmod(0o640)
        os.chown(key, 0, pwd.getpwnam("caddy").pw_gid)
    sys.stdout.buffer.write(
        run(
            [
                "openssl",
                "req",
                "-new",
                "-key",
                str(key),
                "-subj",
                "/CN=openbao.powerlan.empire",
            ]
        )
    )


def install_certificate(root: Path) -> None:
    certificate = sys.stdin.buffer.read(65536)
    with tempfile.TemporaryDirectory() as temporary:
        candidate = Path(temporary) / "server.crt"
        candidate.write_bytes(certificate)
        run(["openssl", "verify", "-CAfile", CA, str(candidate)])
        run(
            [
                "openssl",
                "x509",
                "-in",
                str(candidate),
                "-noout",
                "-checkhost",
                "openbao.powerlan.empire",
                "-checkend",
                "1209600",
            ]
        )
        public = run(["openssl", "x509", "-in", str(candidate), "-pubkey", "-noout"])
        if public != run(
            ["openssl", "pkey", "-in", str(root / "tls/server.key"), "-pubout"]
        ):
            raise ValueError("Certificate does not match the existing private key")
    atomic(root / "tls/server.crt", certificate, mode=0o644)
    run(["systemctl", "reload-or-restart", "caddy"])
    print("Trusted TLS certificate installed")


def apply_password(config: dict, password: str) -> None:
    service = config["service"]
    if service == "forgejo-reader":
        atomic(
            Path("/srv/forgejo/ldap-bind-password"), password.encode(), owner="forgejo"
        )
        run(["runuser", "-u", "forgejo", "--", "bash", config["forgejo_configure"]])
        run(["systemctl", "restart", "forgejo"])
    else:
        # Use Proxmox's locking and update hook without putting the password in argv.
        code = """use PVE::API2::Domains; use PVE::RPCEnvironment; use PVE::Cluster; use JSON::PP;
PVE::Cluster::cfs_update(); my $rpc = PVE::RPCEnvironment->init('cli'); $rpc->set_user('root@pam');
my $data = decode_json(do { local $/; <STDIN> }); PVE::API2::Domains->update($data);"""
        run(
            ["perl", "-e", code],
            data=json.dumps({"realm": "freeipa", "password": password}).encode(),
        )


def verify_application(config: dict) -> None:
    if config["service"] == "forgejo-reader":
        run(
            [
                "curl",
                "--fail",
                "--silent",
                "--show-error",
                "http://127.0.0.1:3000/api/healthz",
            ]
        )
    else:
        run(["pveum", "realm", "sync", "freeipa", "--dry-run", "1"])


def consume(config_file: Path, state: Path) -> None:
    config = json.loads(config_file.read_text())
    service = config["service"]
    if service not in SERVICES:
        raise ValueError("Unknown LDAP password consumer")
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    client = Bao(config["address"], ca=config.get("ca", CA))
    login(client, private_json(state / "credentials.json"))
    try:
        secret = client.request(f"ldap/static-cred/{service}")["data"]
        password = secret["password"]
        if (
            not isinstance(password, str)
            or len(password) < 20
            or secret["dn"] != f"uid={service},{ACCOUNTS}"
        ):
            raise ValueError("Unexpected LDAP credential response")
        stamp = {
            "password_sha256": fingerprint(password),
            "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
        }
        with tempfile.TemporaryDirectory(dir=state) as temporary:
            password_file = Path(temporary) / "password"
            atomic(password_file, password.encode())
            ldap_check(
                secret["dn"],
                password_file,
                url=config.get("ldap_url", LDAP_URL),
                ca=config.get("ldap_ca", CA),
            )
        applied = state / "applied.json"
        if not applied.exists() or private_json(applied) != stamp:
            apply_password(config, password)
            verify_application(config)
            atomic(applied, json.dumps(stamp).encode())
        else:
            verify_application(config)
        client.request(
            f"status/data/{service}", {"data": stamp | {"applied_at": time.time()}}
        )
    finally:
        client.request("auth/token/revoke-self", {})
    print(f"Current LDAP password verified and applied: {service}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/srv/openbao"))
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("init").add_argument(
        "--recipient-file", type=Path, required=True
    )
    commands.add_parser("configure").add_argument("--ldap-password-file", type=Path)
    for name in ("enroll", "activate", "rotate"):
        commands.add_parser(name).add_argument("service", choices=SERVICES)
    for name in (
        "finalize",
        "snapshot",
        "check",
        "csr",
        "install-certificate",
        "export",
    ):
        commands.add_parser(name)
    consumer = commands.add_parser("consume")
    consumer.add_argument("--config", type=Path, required=True)
    consumer.add_argument("--state", type=Path, required=True)
    args = parser.parse_args()
    os.umask(0o077)
    actions = {
        "init": lambda: initialize(args.root, args.recipient_file),
        "configure": lambda: configure(args.root, args.ldap_password_file),
        "enroll": lambda: enroll(args.root, args.service),
        "activate": lambda: activate(args.root, args.service),
        "rotate": lambda: bootstrap_client(args.root).request(
            f"ldap/rotate-role/{args.service}", {}
        ),
        "finalize": lambda: finalize(args.root),
        "snapshot": lambda: snapshot(args.root),
        "check": lambda: check(args.root),
        "csr": lambda: csr(args.root),
        "install-certificate": lambda: install_certificate(args.root),
        "export": lambda: sys.stdout.buffer.write(
            (args.root / "backups/latest.age").read_bytes()
        ),
        "consume": lambda: consume(args.config, args.state),
    }
    actions[args.command]()


if __name__ == "__main__":
    try:
        main()
    except (
        OSError,
        ValueError,
        TypeError,
        RuntimeError,
        KeyError,
        subprocess.TimeoutExpired,
    ) as error:
        print(f"openbao: {error}", file=sys.stderr)
        sys.exit(1)
