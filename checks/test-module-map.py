#!/usr/bin/env python3
"""Regression checks for changes in module usage and absorption candidates."""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from scripts import module_map  # noqa: E402


class ModuleMapTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        files = [
            "flake.nix",
            "modules/parent.nix",
            "modules/child.nix",
            "modules/unseen.nix",
        ]
        files += [
            f"scripts/{name}"
            for name in ("module-graph.nix", "module_map.py", "module-map.html")
        ]
        for name in files:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("{}\n")
        self.raw: module_map.Graphs = {
            "schema": 1,
            "wiring": [{"file": "flake.nix", "parent": None, "disabled": False}],
            "machines": [
                {
                    "name": "fixture",
                    "kind": "NixOS",
                    "home": {},
                    "system": [
                        {
                            "file": "modules/parent.nix",
                            "parent": None,
                            "disabled": False,
                        },
                        {
                            "file": "modules/child.nix",
                            "parent": "modules/parent.nix",
                            "disabled": False,
                        },
                        {
                            "file": "modules/child.nix",
                            "parent": "modules/parent.nix",
                            "disabled": False,
                        },
                    ],
                }
            ],
            "variants": [],
        }

    def test_software_preserves_versions_sources_and_unique_machine_membership(
        self,
    ) -> None:
        pinta = {"name": "pinta", "version": "3.1", "origin": "system"}
        home_pinta = {**pinta, "origin": "home:david"}
        self.raw["software"] = [
            {"name": "wodan", "packages": [pinta, pinta, home_pinta]},
            {"name": "loki", "packages": [{**pinta, "version": "3.0"}]},
        ]
        software = module_map.analyze(self.raw, self.root)["software"]
        self.assertEqual([m["name"] for m in software], ["loki", "wodan"])
        self.assertEqual(len(software[1]["packages"]), 2)
        self.assertEqual(software[0]["packages"][0]["version"], "3.0")
        self.assertEqual(
            {p["origin"] for p in software[1]["packages"]},
            {"system", "home:david"},
        )

    def test_software_kind_comes_from_evaluated_host_source(self) -> None:
        self.raw["software"] = [{"name": "fixture", "packages": []}]
        for kind in ("physical", "virtual"):
            with self.subTest(kind=kind):
                path = f"hosts/{kind}/fixture/default.nix"
                (self.root / path).parent.mkdir(parents=True, exist_ok=True)
                (self.root / path).write_text("{}\n")
                self.raw["compositions"] = [
                    {
                        "name": "fixture",
                        "kind": "NixOS",
                        "nodes": [{"id": "host-fixture", "file": path}],
                        "edges": [],
                    }
                ]
                report = module_map.analyze(self.raw, self.root)
                self.assertEqual(report["software"][0]["kind"], kind)

    def circle_report(self) -> module_map.Report:
        report = module_map.analyze(self.raw, self.root)
        report["software"] = [
            {"name": name, "kind": "physical", "packages": []}
            for name, *_rest in module_map.CIRCLES
        ]
        return report

    def test_six_circles_label_every_represented_membership(self) -> None:
        layout = module_map.physical_circle_layout(self.circle_report())
        self.assertEqual(len(layout["sets"]), 6)
        self.assertEqual(len(layout["regions"]), 23)
        for region in layout["regions"]:
            with self.subTest(mask=region["mask"]):
                mask = 0
                for index, (_name, x, y, radius) in enumerate(layout["sets"]):
                    distance_squared = (region["x"] - x) ** 2 + (-region["y"] - y) ** 2
                    self.assertNotAlmostEqual(distance_squared, radius**2)
                    if distance_squared < radius**2:
                        mask |= 1 << index
                self.assertEqual(mask, region["mask"])

    def test_circle_layout_preserves_all_occupied_combinations(self) -> None:
        report = self.circle_report()
        masks = (1, 2, 6, 8, 32, 34, 36, 37, 38, 39, 42, 47, 54, 55, 62, 63)
        for mask in masks:
            for index, machine in enumerate(report["software"]):
                if mask & (1 << index):
                    machine["packages"].append({"name": f"package-{mask}"})
        layout = module_map.physical_circle_layout(report)
        self.assertEqual(set(layout["groups"]), set(masks))
        self.assertEqual(sum(layout["counts"].values()), len(masks))
        self.assertEqual(layout["extra_empty_masks"], [4, 5, 7, 10, 33, 40, 46])

    def test_circle_layout_rejects_an_unrepresented_combination(self) -> None:
        report = self.circle_report()
        for index in (0, 3):
            report["software"][index]["packages"] = [{"name": "bragi-and-loki-only"}]
        with self.assertRaisesRegex(ValueError, r"occupied combinations \[9\]"):
            module_map.physical_circle_layout(report)

    def test_circle_layout_rejects_changed_physical_hosts(self) -> None:
        report = self.circle_report()
        report["software"].append({"name": "extra", "kind": "physical", "packages": []})
        with self.assertRaisesRegex(ValueError, "changed physical hosts"):
            module_map.physical_circle_layout(report)

    def test_removed_import_becomes_unobserved(self) -> None:
        before = module_map.analyze(self.raw, self.root)
        self.raw["machines"][0]["system"] = self.raw["machines"][0]["system"][:1]
        after = module_map.analyze(self.raw, self.root)
        child = next(m for m in after["modules"] if m["path"] == "modules/child.nix")
        self.assertEqual(child["status"], "unobserved")
        self.assertIn(
            "Changed modules/child.nix: unobserved", module_map.compare(before, after)
        )

    def test_new_unimported_file_is_reported(self) -> None:
        before = module_map.analyze(self.raw, self.root)
        (self.root / "modules/new.nix").write_text("{}\n")
        after = module_map.analyze(self.raw, self.root)
        self.assertIn(
            "Added modules/new.nix: unobserved", module_map.compare(before, after)
        )

    def test_one_importer_same_consumers_is_absorption_signal(self) -> None:
        report = module_map.analyze(self.raw, self.root)
        child = next(m for m in report["modules"] if m["path"] == "modules/child.nix")
        self.assertEqual(child["merge_into"], "modules/parent.nix")
        self.assertEqual(
            report["contexts"][1]["edges"],
            [["modules/parent.nix", "modules/child.nix"]],
        )
        self.raw["variants"] = [
            {
                "name": "independent consumer",
                "kind": "optional",
                "home": {},
                "system": [
                    {"file": "modules/child.nix", "parent": None, "disabled": False}
                ],
            }
        ]
        child = next(
            m
            for m in module_map.analyze(self.raw, self.root)["modules"]
            if m["path"] == "modules/child.nix"
        )
        self.assertIsNone(child["merge_into"])

    def test_disabled_import_does_not_count_as_usage(self) -> None:
        self.raw["machines"][0]["system"][1]["disabled"] = True
        self.raw["machines"][0]["system"][2]["disabled"] = True
        report = module_map.analyze(self.raw, self.root)
        child = next(m for m in report["modules"] if m["path"] == "modules/child.nix")
        self.assertEqual(child["status"], "disabled")
        self.assertNotIn("modules/child.nix", report["contexts"][1]["modules"])

    def test_unknown_schema_fails(self) -> None:
        self.raw["schema"] = 2
        with self.assertRaisesRegex(ValueError, "schema"):
            module_map.analyze(self.raw, self.root)

    def test_new_architecture_roots_are_discovered(self) -> None:
        for directory in (
            "features/fixture",
            "profiles",
            "hosts/physical/fixture",
            "hosts/virtual/fixture",
            "nix",
            "policy",
        ):
            path = self.root / directory / "fixture.nix"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("{}\n")
        report = module_map.analyze(self.raw, self.root)
        self.assertEqual(len(report["modules"]), 10)

    def test_registered_unselected_aspect_is_catalogue_only(self) -> None:
        path = "features/unselected/default.nix"
        (self.root / path).parent.mkdir(parents=True)
        (self.root / path).write_text("{}\n")
        self.raw["catalogue"] = [{"file": path, "parent": None, "disabled": False}]
        report = module_map.analyze(self.raw, self.root)
        module = next(m for m in report["modules"] if m["path"] == path)
        self.assertEqual(module["status"], "wiring-only")
        self.assertEqual(module["contexts"], ["wiring:Registered Den aspects"])

    def test_actual_den_selection_records_feature_owner(self) -> None:
        # Resolve a real feature through Den without constructing an OS closure.
        expression = f"""
          let
            inputs = (builtins.getFlake {json.dumps(str(ROOT))}).inputs;
            inherit (inputs.nixpkgs) lib;
            evaluated = lib.evalModules {{
              specialArgs = {{ inherit inputs; }};
              modules = [ inputs.den.flakeModule inputs.den.flakeOutputs.flake
                inputs.den.flakeOutputs.all {ROOT}/features/annotation/default.nix
                ({{den, ...}}: {{den.hosts.x86_64-linux.fixture.aspect.includes = [den.aspects.annotation];}})
              ];
            }};
          in map (node: {{ id = node.name; file = node.meta.file or ""; }})
            evaluated.config.den.hosts.x86_64-linux.fixture.hasAspect.allAspects
        """
        executable = shutil.which("nix")
        self.assertIsNotNone(executable, "Module-map integration checks require Nix")
        result = subprocess.run(  # noqa: S603
            [executable, "eval", "--impure", "--json", "--expr", expression],
            check=True,
            capture_output=True,
            text=True,
            timeout=90,
        )
        selected = next(
            node for node in json.loads(result.stdout) if node["id"] == "annotation"
        )
        self.assertTrue(selected["file"].endswith("features/annotation/default.nix"))
        path = "features/annotation/default.nix"
        (self.root / path).parent.mkdir(parents=True)
        (self.root / path).write_text("{}\n")
        self.raw["compositions"] = [
            {
                "name": "fixture",
                "kind": "NixOS",
                "nodes": [{"id": "annotation", "file": path}],
                "edges": [],
            }
        ]
        report = module_map.analyze(self.raw, self.root)
        module = next(m for m in report["modules"] if m["path"] == path)
        self.assertEqual((module["status"], module["kind"]), ("used", "feature"))
        self.assertIn("annotation", module_map.composition_dot(report["contexts"][1]))

    def test_embedded_data_cannot_close_script_tag(self) -> None:
        report = self.circle_report()
        report["contexts"][0]["label"] = "</script><script>unsafe()</script>"
        (self.root / "scripts/module-map.html").write_text(
            '<script type="application/json">"__MODULE_MAP_DATA__"</script>'
        )
        with patch.object(
            module_map,
            "run",
            return_value='<svg xmlns="http://www.w3.org/2000/svg"></svg>',
        ):
            rendered = module_map.render_html(report, self.root)
        self.assertEqual(rendered.count("</script>"), 1)
        data = json.loads(rendered.split(">", 1)[1].removesuffix("</script>"))
        self.assertEqual(
            data["report"]["contexts"][0]["label"], report["contexts"][0]["label"]
        )


if __name__ == "__main__":
    unittest.main()
