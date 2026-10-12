#!/usr/bin/env python3
"""Run report orchestration tests offline with real jq and mock scanner CLIs."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MOCK = r"""#!/usr/bin/env python3
import json, os, pathlib, sys
tool = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write(json.dumps({"tool": tool, "args": args,
        "grype_env": {k: v for k, v in os.environ.items() if k.startswith("GRYPE_")}}) + "\n")
if tool == "git":
    print(os.environ["TEST_REPO"])
    sys.exit()
if "--version" in args or args == ["version"]:
    print(tool + " fixture-version")
    sys.exit()
step = tool
value = None
if tool == "nix":
    if args[:2] == ["flake", "archive"]:
        assert "--no-update-lock-file" in args and "--no-write-lock-file" in args
        step, value = "snapshot", {"path": os.environ["TEST_SNAPSHOT"]}
    elif "--apply" in args:
        step, value = "supported-host", os.environ.get("TEST_UNSUPPORTED") != "1"
    elif "build" in args:
        assert "--no-update-lock-file" in args and "--no-write-lock-file" in args
        step = "vex" if "vexFeed" in args[-1] else "system"
        print(os.environ["TEST_VEX"] if step == "vex" else "/nix/store/fixture-system")
    elif args[-1].endswith(".dropped"):
        step, value = "dropped-conditions", {"no-user-mounts": ["fixture-statement"]}
    else:
        step, value = "conditions", {"no-user-mounts": False}
elif tool == "sbomnix":
    assert "--buildtime" not in args
    assert args[0].startswith("path:" + os.environ["TEST_SNAPSHOT"])
    step = "sbom"
    for flag, data in [("--csv", "name,version\nfixture,1\n"),
        ("--cdx", json.dumps({"bomFormat": "CycloneDX", "components": []})),
        ("--spdx", json.dumps({"spdxVersion": "SPDX-2.3", "packages": []}))]:
        pathlib.Path(args[args.index(flag) + 1]).write_text(data)
elif tool == "grype":
    assert args[0] == "--config" and pathlib.Path(args[1]).suffix == ".yaml"
    assert "GRYPE_VEX_DOCUMENTS" not in os.environ
    assert "GRYPE_ONLY_FIXED" not in os.environ
    assert os.environ["GRYPE_DB_AUTO_UPDATE"] == "false"
    args = args[2:]
    if args[:2] == ["db", "update"]:
        step = "grype-db-update"
    elif args[:2] == ["db", "status"]:
        step = "grype-db-status"
        value = {"schemaVersion": "6", "valid": True,
                 "path": os.environ["GRYPE_DB_CACHE_DIR"], "built": "fixture"}
        marker = pathlib.Path(os.environ["GRYPE_DB_CACHE_DIR"]) / "status-read"
        if marker.exists() and os.environ.get("TEST_CHANGED_DB") == "1":
            value["built"] = "changed"
        marker.touch()
    else:
        advisory = "--vex" in args
        step = "grype-advisory" if advisory else "grype-raw"
        assert ("--fail-on" in args) != advisory
        value = {"descriptor": {"name": "grype", "version": "fixture"},
                 "matches": [] if advisory else [{"vulnerability": {"id": "TEST", "severity": "Critical"}}]}
        if advisory:
            value["ignoredMatches"] = [{"vulnerability": {"id": "TEST"},
                                        "appliedIgnoreRules": [{"vex-status": "not_affected"}]}]
elif tool == "osv-scanner":
    step, value = "osv", {"results": []}
elif tool == "vulnix":
    assert "--json" in args
    step, value = "vulnix", []
else:
    raise AssertionError(tool)
if os.environ.get("TEST_BAD_JSON") == step:
    print("broken json")
elif value is not None:
    print(json.dumps(value))
status = json.loads(os.environ.get("TEST_FAILURES", "{}" )).get(step, 0)
if status:
    print("fixture error for " + step, file=sys.stderr)
sys.exit(status)
"""


class SecurityReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        shutil.copy(ROOT / "scripts/github-auth.sh", scripts)
        snapshot = self.root / "snapshot"
        snapshot.mkdir()
        (snapshot / "flake.lock").write_text(
            json.dumps(
                {
                    "nodes": {
                        "root": {"inputs": {"nixos-vex": "nixos-vex"}},
                        "nixos-vex": {"locked": {"rev": "fixture-revision"}},
                    }
                }
            )
        )
        vex = self.root / "vex.json"
        vex.write_text(
            json.dumps(
                {
                    "@context": "https://openvex.dev/ns/v0.2.0",
                    "author": "fixture author",
                    "statements": [],
                }
            )
        )
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        for name in ["git", "nix", "sbomnix", "grype", "osv-scanner", "vulnix"]:
            path = bin_dir / name
            path.write_text(MOCK)
            path.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "TEST_REPO": str(self.root),
            "TEST_SNAPSHOT": str(snapshot),
            "TEST_VEX": str(vex),
            "TEST_CALLS": str(self.root / "calls.jsonl"),
            "GITHUB_TOKEN": "fixture-token",
            "GRYPE_VEX_DOCUMENTS": "must-not-leak.json",
            "GRYPE_ONLY_FIXED": "true",
        }

    def run_report(
        self,
        mode="report",
        failures=None,
        bad_json="",
        unsupported=False,
        changed_db=False,
    ):
        result = subprocess.run(
            [
                str(ROOT / "scripts/security-report.sh"),
                mode,
                "wodan",
                str(self.root / "reports"),
            ],
            env={
                **self.env,
                "TEST_FAILURES": json.dumps(failures or {}),
                "TEST_BAD_JSON": bad_json,
                "TEST_UNSUPPORTED": str(int(unsupported)),
                "TEST_CHANGED_DB": str(int(changed_db)),
            },
            text=True,
            capture_output=True,
        )
        directory = Path(
            result.stdout.splitlines()[0].removeprefix("Security report: ")
        )
        manifest = json.loads((directory / "manifest.json").read_text())
        return result, directory, manifest

    def test_clean_report_and_provenance(self):
        result, directory, manifest = self.run_report()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(manifest["exit_status"], 0)
        self.assertEqual(manifest["upstream_revision"], "fixture-revision")
        self.assertEqual(manifest["source_snapshot"], self.env["TEST_SNAPSHOT"])
        self.assertEqual(manifest["system_path"], "/nix/store/fixture-system")
        self.assertTrue(manifest["advisory_only"])
        self.assertIn(
            "appliedIgnoreRules", (directory / "grype.advisory.json").read_text()
        )
        calls = [
            json.loads(line)
            for line in Path(self.env["TEST_CALLS"]).read_text().splitlines()
        ]
        updates = [
            call
            for call in calls
            if call["tool"] == "grype" and "update" in call["args"]
        ]
        self.assertEqual(len(updates), 1)
        grype_calls = [
            call
            for call in calls
            if call["tool"] == "grype" and "--config" in call["args"]
        ]
        self.assertEqual(
            len({call["grype_env"]["GRYPE_DB_CACHE_DIR"] for call in grype_calls}), 1
        )
        build_calls = [
            call for call in calls if call["tool"] == "nix" and "build" in call["args"]
        ]
        self.assertTrue(
            all(
                call["args"][-1].startswith("path:" + manifest["source_snapshot"])
                for call in build_calls
            )
        )

    def test_raw_critical_remains_blocking_and_all_scans_run(self):
        result, directory, manifest = self.run_report(failures={"grype-raw": 2})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(manifest["steps"]["grype-raw"]["exit_status"], 2)
        self.assertEqual(manifest["steps"]["grype-advisory"]["exit_status"], 0)
        self.assertEqual(manifest["steps"]["osv"]["exit_status"], 0)
        self.assertEqual(manifest["steps"]["vulnix"]["exit_status"], 0)
        self.assertTrue((directory / "grype-raw.stderr.log").read_text())

    def test_other_finding_gates_are_preserved(self):
        for tool, code in [("osv", 1), ("vulnix", 2)]:
            with self.subTest(tool=tool):
                result, _, manifest = self.run_report(failures={tool: code})
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(manifest["steps"][tool]["exit_status"], code)
                self.assertIn("vulnix", manifest["steps"])

    def test_scanner_error_does_not_hide_other_reports(self):
        result, directory, manifest = self.run_report(
            failures={"grype-db-update": 1, "osv": 129}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(manifest["steps"]["vulnix"]["exit_status"], 0)
        self.assertTrue((directory / "vex.openvex.json").exists())
        self.assertTrue((directory / "sbom.cdx.json").exists())

    def test_invalid_json_is_an_error(self):
        for tool in ["grype-raw", "grype-advisory", "osv", "vulnix"]:
            with self.subTest(tool=tool):
                result, _, manifest = self.run_report(bad_json=tool)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotEqual(
                    manifest["steps"][f"validate-{tool}"]["exit_status"], 0
                )
                self.assertIn("vulnix", manifest["steps"])

    def test_fresh_directory_per_run(self):
        _, first, _ = self.run_report()
        _, second, _ = self.run_report()
        self.assertNotEqual(first, second)
        self.assertTrue((first / "manifest.json").exists())

    def test_changed_database_fails_the_run(self):
        result, _, manifest = self.run_report(changed_db=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(manifest["steps"]["compare-grype-db"]["exit_status"], 0)
        self.assertIn("vulnix", manifest["steps"])

    def test_vex_only_does_not_build_system_or_scan(self):
        result, _, manifest = self.run_report(mode="vex")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("system", manifest["steps"])
        self.assertNotIn("grype-raw", manifest["steps"])

    def test_unsupported_host_is_clear_and_does_not_scan(self):
        result, _, manifest = self.run_report(unsupported=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not export system.build.vexFeed", result.stderr)
        self.assertNotIn("grype-raw", manifest["steps"])


if __name__ == "__main__":
    unittest.main()
