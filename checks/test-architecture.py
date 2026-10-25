#!/usr/bin/env python3
"""Mutate actual Den declarations and native module evaluations to test policy gates."""

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NIX = shutil.which("nix")
if NIX is None:
    raise RuntimeError("Architecture tests require Nix.")


class ArchitectureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="nixcfg-policy-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def write(self, name: str, content: str) -> Path:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def evaluate(self, body: str, rule: str | None = None) -> None:
        input_root = str(ROOT)
        den_lock = json.loads((ROOT / "flake.lock").read_text())["nodes"]["den"][
            "locked"
        ]
        den_url = f"github:{den_lock['owner']}/{den_lock['repo']}/{den_lock['rev']}"
        expression = f"""
          let
            inputs = (builtins.getFlake {json.dumps(input_root)}).inputs;
            denInput = builtins.getFlake {json.dumps(den_url)};
            inherit (inputs.nixpkgs) lib;
            root = builtins.toPath {json.dumps(str(self.root))};
            policyRoot = builtins.toPath {json.dumps(str(ROOT / "policy"))};
            {body}
          in if result.valid then true
          else throw (lib.concatMapStringsSep "\\n" (v: v.rule + ": " + v.message) result.report)
        """
        completed = subprocess.run(  # noqa: S603
            [NIX, "eval", "--impure", "--json", "--expr", expression],
            capture_output=True,
            text=True,
            check=False,
            timeout=90,
        )
        if rule is None:
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(json.loads(completed.stdout), True)
        else:
            self.assertNotEqual(completed.returncode, 0, completed.stdout)
            self.assertIn(rule + ":", completed.stderr)

    def den(self, files: dict[str, str], rule: str | None = None) -> None:
        paths = [self.write(name, content) for name, content in files.items()]
        imports = " ".join(str(path) for path in paths)
        self.evaluate(
            f"""
            evaluated = lib.evalModules {{
              specialArgs.inputs = inputs // {{den = denInput;}};
              modules = [denInput.flakeModule denInput.flakeOutputs.flake denInput.flakeOutputs.all {imports}];
            }};
            result = import policyRoot {{inherit lib root; den = evaluated.config.den;}};
            """,
            rule,
        )

    def native(
        self,
        feature: str,
        rule: str | None = None,
        extra: dict[str, str] | None = None,
        selected: tuple[str, ...] = ("annotation",),
        required: tuple[str, ...] = (),
    ) -> None:
        self.write(
            "nix/schema.nix",
            """{lib, ...}: {
              options = {
                home.username = lib.mkOption {type = lib.types.str;};
                home.homeDirectory = lib.mkOption {type = lib.types.str;};
                home.stateVersion = lib.mkOption {type = lib.types.str;};
                home.packages = lib.mkOption {type = lib.types.listOf lib.types.package; default = [];};
                home.file = lib.mkOption {type = lib.types.attrsOf lib.types.anything; default = {};};
                nixcfg.mcp.servers = lib.mkOption {type = lib.types.attrsOf lib.types.anything; default = {};};
              };
            }""",
        )
        self.write("features/annotation/default.nix", feature)
        for name, content in (extra or {}).items():
            self.write(name, content)
        entry = self.write(
            "hosts/physical/fixture/default.nix",
            """{lib, ...}: {
              imports = [../../../nix/schema.nix ../../../features/annotation/default.nix];
              home.username = lib.mkDefault "david";
              home.homeDirectory = "/home/david";
              home.stateVersion = "25.11";
            }""",
        )
        self.evaluate(
            f"""
            evaluated = lib.evalModules {{
              specialArgs.pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
              modules = [{entry}];
            }};
            result = import (policyRoot + "/native.nix") {{
              inherit lib root;
              inherit (evaluated) config options graph;
              class = "homeManager"; selected = builtins.fromJSON {json.dumps(json.dumps(selected))};
              required = builtins.fromJSON {json.dumps(json.dumps(required))};
            }};
            """,
            rule,
        )

    def test_valid_den_feature_composition(self) -> None:
        self.den(
            {
                "features/annotation/default.nix": "{den, ...}: {den.aspects.annotation.homeManager = {};}",
                "profiles/interactive.nix": "{den, ...}: {den.aspects.interactive.includes = [den.aspects.annotation];}",
            }
        )

    def test_feature_cannot_include_profile(self) -> None:
        self.den(
            {
                "features/annotation/default.nix": "{den, ...}: {den.aspects.annotation.includes = [den.aspects.interactive];}",
                "profiles/interactive.nix": "{den.aspects.interactive = {};}",
            },
            "dependency-direction",
        )

    def test_feature_cannot_hide_dependency_in_function(self) -> None:
        self.den(
            {
                "features/annotation/default.nix": "{den, ...}: {den.aspects.annotation.includes = [({host, ...}: den.aspects.interactive)];}",
                "profiles/interactive.nix": "{den.aspects.interactive = {};}",
            },
            "opaque-include",
        )

    def test_authored_cycle_is_rejected(self) -> None:
        self.den(
            {
                "features/a/default.nix": "{den, ...}: {den.aspects.a.includes = [den.aspects.b];}",
                "features/b/default.nix": "{den, ...}: {den.aspects.b.includes = [den.aspects.a];}",
            },
            "include-cycle",
        )

    def test_profile_cannot_implement_native_settings(self) -> None:
        self.den(
            {
                "profiles/interactive.nix": '{den.aspects.interactive.homeManager = {home.stateVersion = "25.11";};}'
            },
            "profile-implementation",
        )

    def test_unknown_aspect_owner_is_rejected(self) -> None:
        self.den(
            {"stray.nix": "{den.aspects.stray.homeManager = {};}"}, "unknown-owner"
        )

    def test_host_outside_physical_or_virtual_is_rejected(self) -> None:
        self.den(
            {"hosts/fixture/default.nix": "{den.aspects.stray.homeManager = {};}"},
            "unknown-owner",
        )

    def test_den_host_directory_has_the_same_owner_as_its_entrypoint(self) -> None:
        entry = self.write(
            "hosts/physical/fixture/default.nix",
            "{den, ...}: {den.aspects.host-fixture.includes = [den.aspects.interactive];}",
        )
        profile = self.write(
            "profiles/interactive.nix", "{den.aspects.interactive = {};}"
        )
        self.evaluate(
            f"""
            evaluated = lib.evalModules {{
              specialArgs.inputs = inputs // {{den = denInput;}};
              modules = [denInput.flakeModule denInput.flakeOutputs.flake
                denInput.flakeOutputs.all {entry.parent} {profile}];
            }};
            result = import policyRoot {{inherit lib root; den = evaluated.config.den;}};
            """
        )

    def test_host_native_imports_preserve_individual_ownership(self) -> None:
        for group in ("physical", "virtual"):
            with self.subTest(group=group):
                entry = self.write(
                    f"hosts/{group}/fixture/default.nix",
                    "{imports = [../other/default.nix];}",
                )
                self.write(f"hosts/{group}/other/default.nix", "{}")
                self.evaluate(
                    f"""
                    evaluated = lib.evalModules {{modules = [{entry}];}};
                    result = import (policyRoot + "/native.nix") {{
                      inherit lib root;
                      inherit (evaluated) config options graph;
                      class = "homeManager";
                    }};
                    """,
                    "native-dependency-direction",
                )

    def test_host_can_import_its_own_hardware(self) -> None:
        entry = self.write(
            "hosts/physical/fixture/default.nix",
            "{imports = [./hardware-configuration.nix];}",
        )
        self.write("hosts/physical/fixture/hardware-configuration.nix", "{}")
        self.evaluate(
            f"""
            evaluated = lib.evalModules {{modules = [{entry}];}};
            result = import (policyRoot + "/native.nix") {{
              inherit lib root;
              inherit (evaluated) config options graph;
              class = "homeManager";
            }};
            """
        )

    def test_platform_restriction_uses_real_home_selection(self) -> None:
        self.den(
            {
                "features/linux-only/default.nix": '{den.aspects.linux-only = {meta.platforms = ["linux"]; homeManager = {};};}',
                "hosts/physical/mac/default.nix": '{den, ...}: {den.homes.aarch64-darwin."alice@mac".aspect = den.aspects.linux-only;}',
            },
            "feature-platform",
        )

    def test_required_selection_cannot_disappear(self) -> None:
        self.native(
            "{}", "required-aspect-selection", selected=(), required=("annotation",)
        )

    def test_missing_mcp_is_rejected(self) -> None:
        self.native("{}", "required-mcp", selected=("mcp",))

    def test_mcp_store_command_is_rejected(self) -> None:
        self.native(
            """{lib, ...}: {
              nixcfg.mcp.servers = lib.genAttrs
                ["agent-memory" "chrome-devtools" "dbhub" "nixos" "node_repl" "playwright"]
                (_: {command = "/nix/store/example/bin/mcp";});
            }""",
            "stable-mcp-command",
            selected=("mcp",),
        )

    def test_native_codex_launchers_cannot_disappear(self) -> None:
        self.native("{}", "native-codex-mcp", selected=("codex-browser",))

    def test_den_inline_identity_keeps_feature_provenance(self) -> None:
        schema = self.write(
            "nix/schema.nix",
            "{lib, ...}: {options.home.username = lib.mkOption {type = lib.types.str;}; options.nixpkgs = lib.mkOption {type = lib.types.attrsOf lib.types.anything; default = {};};}",
        )
        feature = self.write(
            "features/identity/default.nix",
            '{den.aspects.identity.homeManager.home.username = "intruder";}',
        )
        host = self.write(
            "hosts/physical/fixture/default.nix",
            '{den, ...}: {den.homes.x86_64-linux."david@fixture".aspect = den.aspects.identity;}',
        )
        self.evaluate(
            f"""
            fleet = lib.evalModules {{
              specialArgs.inputs = inputs // {{den = denInput;}};
              modules = [denInput.flakeModule denInput.flakeOutputs.flake denInput.flakeOutputs.all {feature} {host}];
            }};
            evaluated = lib.evalModules {{
              modules = [{schema} fleet.config.den.homes.x86_64-linux."david@fixture".mainModule];
            }};
            result = import (policyRoot + "/native.nix") {{
              inherit lib root;
              inherit (evaluated) config options graph;
              class = "homeManager";
              den = fleet.config.den;
            }};
            """,
            "host-value-owner",
        )

    def test_actual_annotation_package_is_present(self) -> None:
        self.native("{pkgs, ...}: {home.packages = [pkgs.pinta];}")

    def test_selected_annotation_without_package_fails(self) -> None:
        self.native("{home.packages = [];}", "required-annotation")

    def test_native_import_cannot_bypass_profile_boundary(self) -> None:
        self.native(
            "{pkgs, ...}: {imports = [../../profiles/bad.nix]; home.packages = [pkgs.pinta];}",
            "native-dependency-direction",
            {"profiles/bad.nix": "{}"},
        )

    def test_public_adapter_can_deliver_feature_implementation(self) -> None:
        self.native(
            "{imports = [../../nix/public.nix];}",
            extra={
                "nix/public.nix": '{ _file = "${__curPos.file}#modules.homeManager.annotation"; imports = [../features/other/_home.nix];}',
                "features/other/_home.nix": "{pkgs, ...}: {home.packages = [pkgs.pinta];}",
            },
        )

    def test_private_cross_feature_import_is_rejected(self) -> None:
        self.native(
            "{pkgs, ...}: {imports = [../other/home.nix]; home.packages = [pkgs.pinta];}",
            "private-feature-import",
            {"features/other/home.nix": "{}"},
        )

    def test_unknown_native_import_is_rejected(self) -> None:
        self.native(
            "{pkgs, ...}: {imports = [../../stray.nix]; home.packages = [pkgs.pinta];}",
            "unknown-native-owner",
            {"stray.nix": "{}"},
        )

    def test_identity_cannot_move_into_feature(self) -> None:
        self.native(
            '{pkgs, ...}: {home.username = "intruder"; home.packages = [pkgs.pinta];}',
            "host-value-owner",
        )


if __name__ == "__main__":
    unittest.main()
