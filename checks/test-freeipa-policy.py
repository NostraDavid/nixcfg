#!/usr/bin/env python3
"""Check the Git policy and the removal path without contacting FreeIPA."""

import importlib.util
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


script = Path(__file__).resolve().parents[1] / "scripts/freeipa-policy.py"
spec = importlib.util.spec_from_file_location("freeipa_policy", script)
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)

known, groups, hostgroups, hbac, sudo_rules, enforce_hbac = policy.policy_groups()
assert known == {
    "admin",
    "engi",
    "ldap_tester",
    "mediacenter",
    "nostradavid",
    "nostradavid-adm",
    "poweremperor",
    "poweremperor-adm",
}
assert groups["grp-forgejo-user"]["members"] == {
    "nostradavid",
    "poweremperor",
    "engi",
    "ldap_tester",
    "nostradavid-adm",
    "poweremperor-adm",
}
assert groups["grp-forgejo-admin"]["members"] == {
    "nostradavid-adm",
    "poweremperor-adm",
}
assert groups["admins"]["members"] == {"admin", "nostradavid-adm", "poweremperor-adm"}
assert groups["media-center"]["members"] == {"mediacenter"}
assert set(hostgroups) == {"hg-identity", "hg-network", "hg-storage"}
assert len(hbac) == len(sudo_rules) == 2
assert not enforce_hbac


def existing_group(name, _env):
    members = (
        {"nostradavid", "poweremperor", "mediacenter"}
        if name == "grp-forgejo-user"
        else set()
    )
    return {"members": members, "posix": groups[name]["posix"]}


with patch.object(policy, "current_group", side_effect=existing_group):
    changes = policy.differences(groups, {})
assert changes["grp-forgejo-user"][1] == {
    "engi",
    "ldap_tester",
    "nostradavid-adm",
    "poweremperor-adm",
}
assert changes["grp-forgejo-user"][2] == {"mediacenter"}

hbac_entry = SimpleNamespace(
    returncode=0,
    stdout=(
        "dn: ipaUniqueID=test,cn=hbac,dc=powerlan,dc=empire\n"
        "memberUser: cn=grp-infra-admin,cn=groups,cn=accounts,dc=powerlan,dc=empire\n"
        "memberHost: cn=hg-identity,cn=hostgroups,cn=accounts,dc=powerlan,dc=empire\n"
        "memberService: cn=sshd,cn=hbacservices,cn=hbac,dc=powerlan,dc=empire\n"
        "ipaEnabledFlag: TRUE\n"
    ),
)
with patch.object(policy, "command", return_value=hbac_entry):
    hbac_state = policy.current_rule("hbac", "hbac-platform-admin", {})
assert hbac_state == {
    "users": set(),
    "groups": {"grp-infra-admin"},
    "hostgroups": {"hg-identity"},
    "services": {"sshd"},
    "enabled": True,
}


def fake_hbactest(args, **_kwargs):
    denied = "--user=engi" in args
    return SimpleNamespace(
        returncode=1 if denied else 0,
        stdout=f"Access granted: {not denied}\n",
        stderr="",
    )


with patch.object(policy.subprocess, "run", side_effect=fake_hbactest):
    policy.test_hbac({})
print("FreeIPA policy expansion and exact membership diff passed.")
