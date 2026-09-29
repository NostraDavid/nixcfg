#!/usr/bin/env python3
"""Reconcile Git-owned FreeIPA groups using a temporary admin Kerberos ticket."""

import os
import re
import secrets
import stat
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / "infra/freeipa/policy.toml"
CA = ROOT / "hosts/wodan/certs/freeipa.crt"
DOMAIN = "dc=powerlan,dc=empire"
GROUP_BASE = f"cn=groups,cn=accounts,{DOMAIN}"
USER_BASE = f"cn=users,cn=accounts,{DOMAIN}"
HOST_BASE = f"cn=computers,cn=accounts,{DOMAIN}"
HOSTGROUP_BASE = f"cn=hostgroups,cn=accounts,{DOMAIN}"
HBAC_BASE = f"cn=hbac,{DOMAIN}"
SUDO_BASE = f"cn=sudorules,cn=sudo,{DOMAIN}"
SERVER = "ldap.powerlan.empire"
NAME = re.compile(r"[a-z][a-z0-9_-]*\Z")
PROXMOX_READER_DN = f"uid=proxmox-reader,cn=sysaccounts,cn=etc,{DOMAIN}"
PROXMOX_READER_PASSWORD = Path.home() / ".local/state/nixcfg/proxmox-ldap-bind-password"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def policy_groups():
    policy = tomllib.loads(POLICY.read_text())
    known = set(policy["people"]["known"])
    teams = policy["teams"]
    roles = policy["roles"]
    grants = policy["grants"]
    require(
        known and all(NAME.fullmatch(name) for name in known), "Invalid account name"
    )
    require(set(teams).isdisjoint(roles), "A team and a role share a name")
    for members in [*teams.values(), *roles.values()]:
        require(set(members) <= known, "Team or role refers to an unknown account")
    require(
        set(roles["platform-admin"]).isdisjoint(
            set().union(*(set(members) for members in teams.values()))
        ),
        "Admin identities must not be team members",
    )

    groups = {
        name: {
            "members": set(members),
            "posix": False,
            "existing": False,
            "description": f"Team {name.removeprefix('team-')}",
        }
        for name, members in teams.items()
    }
    for name, grant in grants.items():
        members = set(grant.get("users", []))
        for team in grant.get("teams", []):
            members.update(teams[team])
        for role in grant.get("roles", []):
            members.update(roles[role])
        require(members <= known, f"{name} refers to an unknown account")
        groups[name] = {
            "members": members,
            "posix": grant.get("posix", False),
            "existing": grant.get("existing", False),
            "description": grant.get("description", name),
        }
    require(
        len(groups) == len(teams) + len(grants), "A team and a grant share a group name"
    )
    require(all(NAME.fullmatch(name) for name in groups), "Invalid group name")
    require(groups["admins"]["existing"], "The built-in admins group must exist")
    require(
        groups["admins"]["members"] == {"admin", *roles["platform-admin"]},
        "The admins group must include admin and every platform admin",
    )
    require(
        groups["grp-forgejo-admin"]["members"] <= groups["grp-forgejo-user"]["members"],
        "Forgejo admins must also be able to sign in",
    )
    hostgroups = {name: set(hosts) for name, hosts in policy["hostgroups"].items()}
    require(all(NAME.fullmatch(name) for name in hostgroups), "Invalid hostgroup name")
    hbac = policy["hbac"]
    sudo_rules = policy["sudo"]
    for name, rule in [*hbac.items(), *sudo_rules.items()]:
        require(NAME.fullmatch(name), "Invalid access rule name")
        require(
            set(rule.get("users", [])) <= known, f"{name} refers to an unknown account"
        )
        require(
            set(rule.get("groups", [])) <= groups.keys(),
            f"{name} refers to an unknown group",
        )
        require(
            set(rule["hostgroups"]) <= hostgroups.keys(),
            f"{name} refers to an unknown hostgroup",
        )
    return (
        known,
        groups,
        hostgroups,
        hbac,
        sudo_rules,
        policy["settings"]["enforce_hbac"],
    )


def command(args, env, *, allow_missing=False):
    result = subprocess.run(args, env=env, text=True, capture_output=True, check=False)
    if result.returncode and not (allow_missing and result.returncode == 32):
        details = result.stderr.strip().splitlines()
        raise RuntimeError(
            f"{' '.join(args[:2])}: {details[-1] if details else result.returncode}"
        )
    return result


def ldap_entry(dn, attributes, env, *, scope="base", filter_string="(objectClass=*)"):
    result = command(
        [
            "ldapsearch",
            "-Q",
            "-Y",
            "GSSAPI",
            "-N",
            "-LLL",
            "-o",
            "ldif-wrap=no",
            "-H",
            f"ldaps://{SERVER}",
            "-s",
            scope,
            "-b",
            dn,
            filter_string,
            *attributes,
        ],
        env,
        allow_missing=True,
    )
    if result.returncode == 32:
        return None
    values = {}
    for line in result.stdout.splitlines():
        if ": " in line:
            key, value = line.split(": ", 1)
            if key.lower() == "dn" and "dn" in values:
                raise RuntimeError(
                    f"LDAP returned multiple entries for {filter_string}"
                )
            values.setdefault(key.lower(), []).append(value)
    return values if "dn" in values else None


def current_group(name, env):
    entry = ldap_entry(f"cn={name},{GROUP_BASE}", ["member", "gidNumber"], env)
    if entry is None:
        return None
    members = set()
    for dn in entry.get("member", []):
        suffix = f",{USER_BASE}"
        if not dn.lower().endswith(suffix):
            raise RuntimeError(f"{name} has a nested or external member: {dn}")
        member = dn[: -len(suffix)]
        if not member.startswith("uid="):
            raise RuntimeError(f"Unexpected member in {name}: {dn}")
        members.add(member.removeprefix("uid="))
    return {"members": members, "posix": "gidnumber" in entry}


def names_in_dns(dns, rdn, base):
    names = set()
    suffix = f",{base}".lower()
    for dn in dns:
        if not dn.lower().endswith(suffix) or not dn.lower().startswith(f"{rdn}="):
            raise RuntimeError(f"Unexpected policy member DN: {dn}")
        names.add(dn[: -len(suffix)].split("=", 1)[1])
    return names


def current_hostgroup(name, env):
    entry = ldap_entry(f"cn={name},{HOSTGROUP_BASE}", ["member"], env)
    return (
        None
        if entry is None
        else names_in_dns(entry.get("member", []), "fqdn", HOST_BASE)
    )


def current_rule(kind, name, env):
    base = HBAC_BASE if kind == "hbac" else SUDO_BASE
    attributes = ["memberUser", "memberHost", "ipaEnabledFlag"]
    if kind == "hbac":
        attributes += [
            "memberService",
            "userCategory",
            "hostCategory",
            "serviceCategory",
        ]
    else:
        attributes += [
            "cmdCategory",
            "userCategory",
            "hostCategory",
            "ipaSudoRunAsUserCategory",
            "ipaSudoRunAsGroupCategory",
            "memberAllowCmd",
            "memberDenyCmd",
        ]
    entry = ldap_entry(base, attributes, env, scope="one", filter_string=f"(cn={name})")
    if entry is None:
        return None
    user_dns = entry.get("memberuser", [])
    group_dns = [dn for dn in user_dns if dn.lower().endswith(f",{GROUP_BASE}".lower())]
    person_dns = [dn for dn in user_dns if dn.lower().endswith(f",{USER_BASE}".lower())]
    require(
        len(group_dns) + len(person_dns) == len(user_dns),
        f"Unknown user member in {name}",
    )
    state = {
        "users": names_in_dns(person_dns, "uid", USER_BASE),
        "groups": names_in_dns(group_dns, "cn", GROUP_BASE),
        "hostgroups": names_in_dns(entry.get("memberhost", []), "cn", HOSTGROUP_BASE),
        "enabled": entry.get("ipaenabledflag", []) == ["TRUE"],
    }
    if kind == "hbac":
        state["services"] = names_in_dns(
            entry.get("memberservice", []), "cn", f"cn=hbacservices,{HBAC_BASE}"
        )
        require(
            not any(
                entry.get(f"{category}category")
                for category in ("user", "host", "service")
            ),
            f"{name} has an unrestricted HBAC category",
        )
    else:
        require(
            entry.get("cmdcategory") == ["all"]
            and entry.get("ipasudorunasusercategory") == ["all"]
            and entry.get("ipasudorunasgroupcategory") == ["all"]
            and not any(
                entry.get(f"{category}category") for category in ("user", "host")
            )
            and not entry.get("memberallowcmd")
            and not entry.get("memberdenycmd"),
            f"{name} has unexpected sudo categories or commands",
        )
    return state


def differences(groups, env):
    changes = {}
    for name, desired in sorted(groups.items()):
        current = current_group(name, env)
        if current is None and desired["existing"]:
            raise RuntimeError(f"Required existing group is missing: {name}")
        if (
            current is not None
            and name != "admins"
            and current["posix"] != desired["posix"]
        ):
            raise RuntimeError(f"Unexpected POSIX type for {name}")
        before = current["members"] if current else set()
        changes[name] = (
            current is None,
            desired["members"] - before,
            before - desired["members"],
        )
    return changes


def access_differences(hostgroups, hbac, sudo_rules, env):
    changes = {}
    for name, hosts in sorted(hostgroups.items()):
        current = current_hostgroup(name, env)
        changes[("hostgroup", name)] = (
            current is None,
            {"hosts": hosts - (current or set())},
            {"hosts": (current or set()) - hosts},
            False,
        )
    for kind, rules in (("hbac", hbac), ("sudo", sudo_rules)):
        for name, desired in sorted(rules.items()):
            current = current_rule(kind, name, env)
            fields = (
                ("users", "groups", "hostgroups", "services")
                if kind == "hbac"
                else ("users", "groups", "hostgroups")
            )
            added = {
                field: set(desired.get(field, []))
                - (current[field] if current else set())
                for field in fields
            }
            removed = {
                field: (current[field] if current else set())
                - set(desired.get(field, []))
                for field in fields
            }
            changes[(kind, name)] = (
                current is None,
                added,
                removed,
                current is not None and not current["enabled"],
            )
    return changes


def print_access_changes(changes):
    drift = False
    for (kind, name), (create, added, removed, disabled) in changes.items():
        if create:
            print(f"+ {kind} {name}")
            drift = True
        if disabled:
            print(f"+ enable {kind} {name}")
            drift = True
        for field, members in added.items():
            for member in sorted(members):
                print(f"+ {kind} {name} {field}: {member}")
                drift = True
        for field, members in removed.items():
            for member in sorted(members):
                print(f"- {kind} {name} {field}: {member}")
                drift = True
    return drift


def print_changes(changes):
    any_change = False
    for name, (create, added, removed) in changes.items():
        if create:
            print(f"+ group {name}")
            any_change = True
        for member in sorted(added):
            print(f"+ {name}: {member}")
            any_change = True
        for member in sorted(removed):
            print(f"- {name}: {member}")
            any_change = True
    return any_change


def ipa(args, env):
    command(["ipa", *args], env)


def apply_groups(groups, changes, env):
    for name, (create, _, _) in changes.items():
        if create:
            ipa(
                [
                    "group-add",
                    name,
                    "--nonposix",
                    f"--desc={groups[name]['description']}",
                ],
                env,
            )
    # Add before removing so group updates never empty an app access group mid-run.
    for name, (_, added, _) in changes.items():
        for member in sorted(added):
            ipa(["group-add-member", name, f"--users={member}"], env)
    for name, (_, _, removed) in changes.items():
        for member in sorted(removed):
            ipa(["group-remove-member", name, f"--users={member}"], env)
    if print_changes(differences(groups, env)):
        raise RuntimeError("FreeIPA still differs from Git after apply")


def apply_access(changes, env):
    for (kind, name), (create, _, _, _) in changes.items():
        if not create:
            continue
        if kind == "hostgroup":
            ipa(["hostgroup-add", name, f"--desc=Host group {name}"], env)
        elif kind == "hbac":
            ipa(["hbacrule-add", name, f"--desc=Managed by nixcfg: {name}"], env)
        else:
            ipa(
                [
                    "sudorule-add",
                    name,
                    "--cmdcat=all",
                    "--runasusercat=all",
                    "--runasgroupcat=all",
                ],
                env,
            )
    commands = {
        ("hostgroup", "hosts"): ("hostgroup", "member", "hosts"),
        ("hbac", "users"): ("hbacrule", "user", "users"),
        ("hbac", "groups"): ("hbacrule", "user", "groups"),
        ("hbac", "hostgroups"): ("hbacrule", "host", "hostgroups"),
        ("hbac", "services"): ("hbacrule", "service", "hbacsvcs"),
        ("sudo", "users"): ("sudorule", "user", "users"),
        ("sudo", "groups"): ("sudorule", "user", "groups"),
        ("sudo", "hostgroups"): ("sudorule", "host", "hostgroups"),
    }
    for action, index in (("add", 1), ("remove", 2)):
        for (kind, name), change in changes.items():
            for field, members in change[index].items():
                prefix, target, option = commands[(kind, field)]
                for member in sorted(members):
                    ipa(
                        [f"{prefix}-{action}-{target}", name, f"--{option}={member}"],
                        env,
                    )
    for (kind, name), (_, _, _, disabled) in changes.items():
        if disabled:
            ipa([f"{kind}rule-enable", name], env)


def allow_all_enabled(env):
    entry = ldap_entry(
        HBAC_BASE, ["ipaEnabledFlag"], env, scope="one", filter_string="(cn=allow_all)"
    )
    require(entry is not None, "The built-in allow_all rule is missing")
    return entry.get("ipaenabledflag") == ["TRUE"]


def test_hbac(env):
    cases = [
        (
            "nostradavid-adm",
            "ldap.powerlan.empire",
            "sshd",
            "hbac-platform-admin",
            True,
        ),
        (
            "poweremperor-adm",
            "pihole.powerlan.empire",
            "sudo",
            "hbac-platform-admin",
            True,
        ),
        ("admin", "ldap.powerlan.empire", "sshd", "hbac-admin-recovery", True),
        ("engi", "ldap.powerlan.empire", "sshd", "hbac-platform-admin", False),
    ]
    for user, host, service, rule, expected in cases:
        result = subprocess.run(
            [
                "ipa",
                "hbactest",
                f"--user={user}",
                f"--host={host}",
                f"--service={service}",
                f"--rules={rule}",
            ],
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        require(
            "Access granted: True" in result.stdout
            or "Access granted: False" in result.stdout,
            f"HBAC test could not run: {user} {result.stderr.strip()}",
        )
        actual = "Access granted: True" in result.stdout
        require(actual == expected, f"HBAC test failed: {user} {host} {service}")


def bootstrap_proxmox_reader(env):
    password_path = PROXMOX_READER_PASSWORD
    entry = ldap_entry(PROXMOX_READER_DN, ["uid"], env)
    if entry and not password_path.is_file():
        raise RuntimeError(
            "proxmox-reader exists, but its local password file is missing"
        )
    if not password_path.exists():
        password_path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        password_path.parent.chmod(0o700)
        with os.fdopen(
            os.open(password_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w"
        ) as stream:
            stream.write(secrets.token_urlsafe(48))
    require(not password_path.is_symlink(), "Password file must not be a symlink")
    require(
        stat.S_IMODE(password_path.stat().st_mode) == 0o600,
        f"Password file must have mode 0600: {password_path}",
    )
    if not entry:
        password = password_path.read_text().strip()
        ldif = (
            f"dn: {PROXMOX_READER_DN}\n"
            "objectClass: account\nobjectClass: simpleSecurityObject\n"
            "uid: proxmox-reader\n"
            f"userPassword: {password}\n"
            "passwordExpirationTime: 20380119031407Z\nnsIdleTimeout: 0\n"
        )
        result = subprocess.run(
            ["ldapadd", "-Q", "-Y", "GSSAPI", "-N", "-H", f"ldaps://{SERVER}"],
            input=ldif,
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )
        if result.returncode:
            details = result.stderr.strip().splitlines()
            raise RuntimeError(
                details[-1] if details else "Could not create proxmox-reader"
            )
    command(
        [
            "ldapwhoami",
            "-x",
            "-H",
            f"ldaps://{SERVER}",
            "-D",
            PROXMOX_READER_DN,
            "-y",
            str(password_path),
        ],
        env,
    )
    for base, filter_string, expected_dn in (
        (
            USER_BASE,
            f"(&(uid=nostradavid)(memberOf=cn=grp-ro-monitor,{GROUP_BASE}))",
            f"uid=nostradavid,{USER_BASE}",
        ),
        (
            GROUP_BASE,
            "(&(cn=grp-ro-monitor)(objectClass=groupOfNames))",
            f"cn=grp-ro-monitor,{GROUP_BASE}",
        ),
    ):
        result = command(
            [
                "ldapsearch",
                "-x",
                "-LLL",
                "-H",
                f"ldaps://{SERVER}",
                "-D",
                PROXMOX_READER_DN,
                "-y",
                str(password_path),
                "-b",
                base,
                filter_string,
                "dn",
            ],
            env,
        )
        require(
            f"dn: {expected_dn}" in result.stdout.splitlines(),
            f"proxmox-reader cannot search {expected_dn}",
        )
    print(f"proxmox-reader works; password remains in {password_path}.")


def runtime_env(temp_dir):
    (temp_dir / "default.conf").write_text(
        "[global]\n"
        f"host = {SERVER}\nserver = {SERVER}\n"
        "domain = powerlan.empire\nrealm = POWERLAN.EMPIRE\n"
        f"basedn = {DOMAIN}\nxmlrpc_uri = https://{SERVER}/ipa/xml\n"
    )
    (temp_dir / "ca.crt").symlink_to(CA)
    (temp_dir / "krb5.conf").write_text(
        "[libdefaults]\n"
        "default_realm = POWERLAN.EMPIRE\n"
        "dns_lookup_kdc = false\ndns_lookup_realm = false\nrdns = false\n"
        "udp_preference_limit = 1\n"
        "[realms]\nPOWERLAN.EMPIRE = {\n    kdc = ldap.powerlan.empire\n}\n"
        "[domain_realm]\n.powerlan.empire = POWERLAN.EMPIRE\n"
    )
    return os.environ | {
        "IPA_CONFDIR": str(temp_dir),
        "KRB5_CONFIG": str(temp_dir / "krb5.conf"),
        "KRB5CCNAME": f"FILE:{temp_dir / 'krb5cc'}",
        "LDAPTLS_CACERT": str(CA),
        "SSL_CERT_FILE": str(CA),
    }


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {
        "validate",
        "plan",
        "apply",
        "check",
        "bootstrap-proxmox-reader",
    }:
        raise SystemExit(
            "Usage: freeipa-policy.py {validate|plan|apply|check|bootstrap-proxmox-reader}"
        )
    known, groups, hostgroups, hbac, sudo_rules, enforce_hbac = policy_groups()
    if sys.argv[1] == "validate":
        print(
            f"Valid policy: {len(known)} accounts, {len(groups)} user groups, "
            f"{len(hostgroups)} hostgroups, {len(hbac)} HBAC rules, "
            f"{len(sudo_rules)} sudo rules."
        )
        return
    with tempfile.TemporaryDirectory(prefix="freeipa-policy-", dir="/tmp") as directory:
        env = runtime_env(Path(directory))
        print(
            "FreeIPA admin password is requested by Kerberos; it is not stored in Git.",
            flush=True,
        )
        subprocess.run(["kinit", "admin@POWERLAN.EMPIRE"], env=env, check=True)
        if sys.argv[1] == "bootstrap-proxmox-reader":
            bootstrap_proxmox_reader(env)
            return
        forgejo_emails = set()
        for user in sorted(known):
            entry = ldap_entry(f"uid={user},{USER_BASE}", ["uid", "mail"], env)
            if entry is None:
                raise RuntimeError(f"Policy account is missing from FreeIPA: {user}")
            if user in groups["grp-forgejo-user"]["members"]:
                email = entry.get("mail", [""])[0].lower()
                require(
                    email and email not in forgejo_emails,
                    f"Missing or duplicate Forgejo mail: {user}",
                )
                forgejo_emails.add(email)
        for hosts in hostgroups.values():
            for host in sorted(hosts):
                if ldap_entry(f"fqdn={host},{HOST_BASE}", ["fqdn"], env) is None:
                    raise RuntimeError(f"Policy host is missing from FreeIPA: {host}")
        group_changes = differences(groups, env)
        access_changes = access_differences(hostgroups, hbac, sudo_rules, env)
        drift = print_changes(group_changes) | print_access_changes(access_changes)
        if enforce_hbac and allow_all_enabled(env):
            print("- disable built-in HBAC rule allow_all")
            drift = True
        if not drift:
            print("FreeIPA policy matches Git.")
        if sys.argv[1] == "apply" and drift:
            apply_groups(groups, group_changes, env)
            apply_access(access_changes, env)
            if print_access_changes(
                access_differences(hostgroups, hbac, sudo_rules, env)
            ):
                raise RuntimeError(
                    "FreeIPA access rules still differ from Git after apply"
                )
            if enforce_hbac and allow_all_enabled(env):
                test_hbac(env)
                ipa(["hbacrule-disable", "allow_all"], env)
                require(not allow_all_enabled(env), "Could not disable allow_all")
            print("FreeIPA policy matches Git.")
        elif sys.argv[1] == "check" and drift:
            raise SystemExit(1)


if __name__ == "__main__":
    try:
        main()
    except (KeyError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"FreeIPA policy error: {error}") from error
