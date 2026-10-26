#!/usr/bin/env python3
"""Reconcile the public Headlamp PKCE client and existing LDAP group mapping."""

import argparse
import json
import re
import sys

from openbao import Bao

GROUP = "grp-infra-admin"
CLIENT = "headlamp"
KEY = "k3s-headlamp"
ASSIGNMENT = "k3s-infra-admin"
ISSUER_HOST = "https://openbao.powerlan.empire"
ISSUER = ISSUER_HOST + "/v1/identity/oidc/provider/k3s"
CALLBACK = "https://k3s.powerlan.empire/oidc-callback"


def ldap_group(client: Bao) -> tuple[str, str]:
    """Map only the existing FreeIPA group through its LDAP mount alias."""
    ldap = client.request("sys/auth")["data"]["ldap/"]
    accessor = ldap["accessor"]
    if ldap["type"] != "ldap" or not re.fullmatch(r"auth_ldap_[A-Za-z0-9]+", accessor):
        raise ValueError("Expected the existing LDAP authentication mount")
    group = client.optional(f"identity/group/name/{GROUP}")
    if group:
        if group["data"]["type"] != "external":
            raise ValueError("Existing identity group is not an external LDAP group")
        group_id = group["data"]["id"]
    else:
        group_id = client.request(
            "identity/group", {"name": GROUP, "type": "external", "policies": []}
        )["data"]["id"]
    aliases = client.optional("identity/group-alias/id?list=true")
    matches = []
    for alias_id in (aliases or {}).get("data", {}).get("keys", []):
        alias = client.request(f"identity/group-alias/id/{alias_id}")["data"]
        if alias["name"] == GROUP and alias["mount_accessor"] == accessor:
            matches.append(alias)
    if matches:
        if len(matches) != 1 or matches[0]["canonical_id"] != group_id:
            raise ValueError("Conflicting LDAP group alias; refusing to reassign it")
    else:
        client.request(
            "identity/group-alias",
            {"name": GROUP, "mount_accessor": accessor, "canonical_id": group_id},
        )
    return accessor, group_id


def reconcile(client: Bao) -> dict:
    """Only configure the named resources; existing human policies stay intact."""
    previous = client.optional(f"identity/oidc/client/{CLIENT}")
    if previous and (
        previous["data"]["key"] != KEY or previous["data"]["client_type"] != "public"
    ):
        raise ValueError("Existing OIDC client is not the expected public PKCE client")
    accessor, group_id = ldap_group(client)
    client.request(
        f"identity/oidc/assignment/{ASSIGNMENT}",
        {"entity_ids": [], "group_ids": [group_id]},
    )
    if client.optional(f"identity/oidc/key/{KEY}") is None:
        client.request(
            f"identity/oidc/key/{KEY}",
            {"algorithm": "RS256", "rotation_period": "24h", "verification_ttl": "24h"},
        )
    client.request(
        f"identity/oidc/client/{CLIENT}",
        {
            "redirect_uris": [CALLBACK],
            "assignments": [ASSIGNMENT],
            "key": KEY,
            "client_type": "public",
            "id_token_ttl": "15m",
            "access_token_ttl": "15m",
        },
    )
    registered = client.request(f"identity/oidc/client/{CLIENT}")["data"]
    client_id = registered["client_id"]
    if not re.fullmatch(r"[A-Za-z0-9]{32}", client_id):
        raise ValueError("Unexpected OIDC client identifier")
    client.request(
        f"identity/oidc/key/{KEY}",
        {
            "algorithm": "RS256",
            "allowed_client_ids": [client_id],
            "rotation_period": "24h",
            "verification_ttl": "24h",
        },
    )
    # LDAP alias names are DNs; metadata.name is the authenticated login name.
    template = (
        '{"preferred_username":{{identity.entity.aliases.'
        + accessor
        + '.metadata.name}},"groups":{{identity.entity.groups.names}}}'
    )
    client.request("identity/oidc/scope/k3s", {"template": template})
    client.request(
        "identity/oidc/provider/k3s",
        {
            "issuer": ISSUER_HOST,
            "allowed_client_ids": [client_id],
            "scopes_supported": ["k3s"],
        },
    )
    discovery = client.request(
        "identity/oidc/provider/k3s/.well-known/openid-configuration"
    )
    if discovery["issuer"] != ISSUER:
        raise ValueError("OIDC discovery returned an unexpected issuer")
    return {"client_id": client_id, "issuer": ISSUER}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["configure", "check"])
    parser.add_argument("--ca", default="/etc/ssl/certs/ca-certificates.crt")
    args = parser.parse_args()
    if args.command == "check":
        public = Bao(ISSUER_HOST, ca=args.ca)
        if (
            public.request(
                "identity/oidc/provider/k3s/.well-known/openid-configuration"
            )["issuer"]
            != ISSUER
        ):
            raise ValueError("Unexpected OIDC issuer")
        print("ok")
        return
    token = sys.stdin.read(4097).strip()
    if not token or len(token) > 4096 or any(c.isspace() for c in token):
        raise ValueError("Provide a temporary administrator token on stdin")
    client = Bao(ISSUER_HOST, token=token, ca=args.ca)
    try:
        print(json.dumps(reconcile(client)))
    finally:
        client.request("auth/token/revoke-self", {})


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyError, ValueError, RuntimeError) as error:
        print(f"headlamp-identity: {error}", file=sys.stderr)
        sys.exit(1)
