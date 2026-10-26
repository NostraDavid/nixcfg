#!/usr/bin/env python3
"""Ensure identity reconciliation refuses conflicting owners before writing."""

import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
SPEC = importlib.util.spec_from_file_location(
    "headlamp_identity", ROOT / "scripts/headlamp-identity.py"
)
identity = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(identity)


class ReadOnlyFixture:
    def __init__(self, responses: dict) -> None:
        self.responses = responses

    def optional(self, path: str) -> dict | None:
        return self.responses.get(path)

    def request(self, path: str, data: dict | None = None) -> dict:
        if data is not None:
            raise AssertionError(
                "Conflicting identity configuration must not be modified"
            )
        return self.responses[path]


class IdentityBoundaryTests(unittest.TestCase):
    def test_username_uses_ldap_login_metadata_instead_of_distinguished_name(
        self,
    ) -> None:
        client = Mock()
        client.optional.return_value = None
        client.request.side_effect = lambda path, _data=None: {
            "identity/oidc/client/headlamp": {"data": {"client_id": "a" * 32}},
            "identity/oidc/provider/k3s/.well-known/openid-configuration": {
                "issuer": identity.ISSUER
            },
        }.get(path, {})
        with patch.object(
            identity, "ldap_group", return_value=("auth_ldap_fixture", "group")
        ):
            identity.reconcile(client)
        scope = next(
            call.args[1]
            for call in client.request.call_args_list
            if call.args[0] == "identity/oidc/scope/k3s"
        )
        self.assertIn(
            "{{identity.entity.aliases.auth_ldap_fixture.metadata.name}}",
            scope["template"],
        )
        self.assertNotIn(
            "{{identity.entity.aliases.auth_ldap_fixture.name}}", scope["template"]
        )

    def test_confidential_client_is_not_silently_downgraded(self) -> None:
        client = ReadOnlyFixture(
            {
                "identity/oidc/client/headlamp": {
                    "data": {"key": "k3s-headlamp", "client_type": "confidential"}
                }
            }
        )
        with self.assertRaisesRegex(ValueError, "public PKCE"):
            identity.reconcile(client)

    def test_foreign_signing_key_is_not_reassigned(self) -> None:
        client = ReadOnlyFixture(
            {
                "identity/oidc/client/headlamp": {
                    "data": {"key": "another-app", "client_type": "public"}
                }
            }
        )
        with self.assertRaisesRegex(ValueError, "public PKCE"):
            identity.reconcile(client)

    def test_internal_group_is_not_changed_into_an_ldap_group(self) -> None:
        client = ReadOnlyFixture(
            {
                "sys/auth": {
                    "data": {"ldap/": {"type": "ldap", "accessor": "auth_ldap_fixture"}}
                },
                "identity/group/name/grp-infra-admin": {"data": {"type": "internal"}},
            }
        )
        with self.assertRaisesRegex(ValueError, "external LDAP"):
            identity.ldap_group(client)


if __name__ == "__main__":
    unittest.main()
