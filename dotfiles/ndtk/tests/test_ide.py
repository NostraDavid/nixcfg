from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import subprocess as sp
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from types import ModuleType
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).resolve().parents[1] / ".local/bin/ide.py"
sys.path.insert(0, str(SCRIPT.parent))


def load_ide() -> ModuleType:
    spec = importlib.util.spec_from_file_location("ide_under_test", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


ide = load_ide()


class IdeProcessTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        home = Path(self.temp.name)
        self.project = home / "dev/NostraDavid/wow-forever"
        (self.project / "worktree.git").mkdir(parents=True)
        self.bin = home / "bin"
        self.bin.mkdir()
        self.launches = home / "launches.jsonl"
        code = self.bin / "code"
        code.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "if sys.argv[1:] == ['--version']:\n"
            "    print('test code')\n"
            "else:\n"
            "    with open(os.environ['IDE_TEST_LAUNCHES'], 'a') as file:\n"
            "        file.write(json.dumps(sys.argv[1:]) + '\\n')\n"
            "    sys.exit(int(os.environ.get('IDE_TEST_CODE_EXIT', '0')))\n"
        )
        code.chmod(0o755)
        fzf = self.bin / "fzf"
        fzf.write_text(
            f"#!{sys.executable}\n"
            "import os, sys\n"
            "choices = sys.stdin.read().splitlines()\n"
            "selected = os.environ.get('IDE_TEST_SELECTION', '')\n"
            "if selected in choices:\n"
            "    print(selected)\n"
            "else:\n"
            "    sys.exit(1)\n"
        )
        fzf.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(
            HOME=str(home),
            PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            IDE_TEST_LAUNCHES=str(self.launches),
            UV_PYTHON_INSTALL_DIR=str(Path.home() / ".local/share/uv/python"),
            UV_CACHE_DIR=str(Path.home() / ".cache/uv"),
        )

    def invoke(self, *args: str) -> sp.CompletedProcess[str]:
        return sp.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=self.temp.name,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )

    def test_search_term_launches_project_in_new_window(self) -> None:
        settings_path = self.project / ".vscode/settings.json"
        settings_path.parent.mkdir()
        settings_path.write_text('{"editor.fontSize": 14}')
        result = self.invoke("forever")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.launches.read_text()), ["--new-window", str(self.project)]
        )
        settings = json.loads(settings_path.read_text())
        expected = (
            sp.run(
                [
                    sys.executable,
                    str(SCRIPT.with_name("project_color.py")),
                    "wow-forever",
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            .stdout.strip()
            .lower()
        )
        self.assertEqual(settings["peacock.color"], expected)
        self.assertEqual(
            settings["workbench.colorCustomizations"]["titleBar.activeBackground"],
            expected,
        )
        self.assertEqual(settings["editor.fontSize"], 14)

    def test_interactive_selection_launches_once_without_worktree_selection(
        self,
    ) -> None:
        self.env["IDE_TEST_SELECTION"] = "NostraDavid/wow-forever"
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.launches.read_text()), ["--new-window", str(self.project)]
        )

    def test_ambiguous_search_prompts_for_project(self) -> None:
        (self.project.parent / "forever-other" / "worktree.git").mkdir(parents=True)
        self.env["IDE_TEST_SELECTION"] = "NostraDavid/wow-forever"
        result = self.invoke("forever")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.launches.read_text()), ["--new-window", str(self.project)]
        )

    def test_existing_project_colors_are_preserved(self) -> None:
        settings_path = self.project / ".vscode/settings.json"
        settings_path.parent.mkdir()
        for existing in (
            {"peacock.color": "#123456", "peacock.remoteColor": "#abcdef"},
            {"workbench.colorCustomizations": {"titleBar.activeBackground": "#123456"}},
        ):
            with self.subTest(existing=existing):
                settings_path.write_text(json.dumps(existing))
                result = self.invoke("forever")
                self.assertEqual(result.returncode, 0, result.stderr)
                settings = json.loads(settings_path.read_text())
                for key, value in existing.items():
                    if key == "workbench.colorCustomizations":
                        for color_key, color in value.items():
                            self.assertEqual(settings[key][color_key], color)
                    else:
                        self.assertEqual(settings[key], value)
                self.assertIn(
                    "statusBar.background", settings["workbench.colorCustomizations"]
                )
                if "peacock.color" in existing:
                    self.assertEqual(
                        settings["workbench.colorCustomizations"][
                            "statusBar.background"
                        ],
                        existing["peacock.color"],
                    )

    def test_missing_window_title_is_restored_in_vscode_json(self) -> None:
        settings_path = self.project / ".vscode/settings.json"
        settings_path.parent.mkdir()
        settings_path.write_text(
            '{"peacock.color": "#123456", "editor.fontFamily": "x,}",}'
        )
        for _ in range(2):
            result = self.invoke("forever")
            self.assertEqual(result.returncode, 0, result.stderr)
            settings = json.loads(settings_path.read_text())
            self.assertEqual(settings.pop("window.title"), "wow-forever")
            self.assertEqual(settings["peacock.color"], "#123456")
            self.assertEqual(settings["editor.fontFamily"], "x,}")
            self.assertEqual(
                settings["workbench.colorCustomizations"]["statusBar.background"],
                "#123456",
            )
            settings_path.write_text(json.dumps(settings))

    def test_existing_window_title_is_preserved(self) -> None:
        settings_path = self.project / ".vscode/settings.json"
        settings_path.parent.mkdir()
        for title in ("Mijn eigen titel", ""):
            with self.subTest(title=title):
                settings_path.write_text(json.dumps({"window.title": title}))
                result = self.invoke("forever")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    json.loads(settings_path.read_text())["window.title"], title
                )

    def test_settings_with_comments_are_not_overwritten(self) -> None:
        settings_path = self.project / ".vscode/settings.json"
        settings_path.parent.mkdir()
        original = '{\n  // keep this comment\n  "editor.fontSize": 14,\n}\n'
        settings_path.write_text(original)
        result = self.invoke("forever")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(settings_path.read_text(), original)
        self.assertIn("settings", result.stderr.lower())

    def test_invalid_existing_base_color_is_not_overwritten(self) -> None:
        settings_path = self.project / ".vscode/settings.json"
        settings_path.parent.mkdir()
        settings_path.write_text('{"peacock.color": "invalid"}')
        result = self.invoke("forever")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(settings_path.read_text())["peacock.color"], "invalid"
        )
        self.assertIn("invalid", result.stderr.lower())

    def test_nested_worktree_path_launches_project(self) -> None:
        trunk = self.project / "trunk"
        sp.run(["git", "init", "--quiet", str(trunk)], check=True)
        nested = trunk / "src"
        nested.mkdir()
        result = self.invoke(str(nested))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.launches.read_text()), ["--new-window", str(self.project)]
        )

    def test_cancelled_selection_does_not_launch(self) -> None:
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No repository selected", result.stderr)
        self.assertFalse(self.launches.exists())

    def test_dry_run_does_not_launch(self) -> None:
        result = self.invoke("--dry-run", "forever")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.project), result.stdout)
        self.assertFalse(self.launches.exists())

    def test_vscode_failure_is_returned(self) -> None:
        self.env["IDE_TEST_CODE_EXIT"] = "7"
        result = self.invoke("forever")
        self.assertEqual(result.returncode, 7, result.stderr)


class IdeRoutingTests(unittest.TestCase):
    def test_subdirectory_opens_worktree_root_without_changing_option_values(
        self,
    ) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            sp.run(["git", "init", "--quiet", str(root)], check=True)
            subdir = root / "subdir"
            subdir.mkdir()
            with (
                patch.object(
                    ide,
                    "parse_args",
                    return_value=ide.CliArgs(
                        ("--user-data-dir", str(subdir), str(subdir)),
                        False,
                        False,
                        True,
                    ),
                ),
                patch.object(ide, "find_code_command", return_value=["code-cli"]),
                patch.object(ide, "clean_vscode_env", return_value={}),
                patch.object(ide, "ensure_workspace_settings") as settings,
                patch.object(ide, "launch_code", return_value=0) as launch,
            ):
                self.assertEqual(ide.main(), 0)
            launch.assert_called_once_with(
                ["code-cli", "--new-window", "--user-data-dir", str(subdir), str(root)],
                {},
            )
            settings.assert_called_once_with(root)

    def test_find_code_command_falls_back_to_macos_app_bundle(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            path_dir = root / "bin"
            path_dir.mkdir()
            path_cli = path_dir / "code"
            path_cli.write_text("#!/bin/sh\nexit 1\n")
            path_cli.chmod(0o755)
            app_cli = (
                root
                / "Applications"
                / "Visual Studio Code.app"
                / "Contents"
                / "Resources"
                / "app"
                / "bin"
                / "code"
            )
            app_cli.parent.mkdir(parents=True)
            app_cli.write_text("#!/bin/sh\nprintf '1.0\\n'\n")
            app_cli.chmod(0o755)

            with (
                patch.dict(ide.os.environ, {"PATH": str(path_dir)}),
                patch.object(ide.sys, "platform", "darwin"),
                patch.object(ide.Path, "home", return_value=root),
            ):
                self.assertEqual(ide.find_code_command(), [str(app_cli)])

    def test_empty_invocation_selects_project(self) -> None:
        picker_result = sp.CompletedProcess(
            args=["project_picker"],
            returncode=0,
            stdout="/repos/example\n",
            stderr="",
        )
        launch = Mock(return_value=0)

        with (
            patch.object(
                ide,
                "parse_args",
                return_value=ide.CliArgs((), False, False, False),
            ),
            patch.object(ide, "find_code_command", return_value=["code-cli"]),
            patch.object(ide, "clean_vscode_env", return_value={}),
            patch.object(ide, "find_project_picker", return_value="project_picker"),
            patch.object(ide, "run", return_value=picker_result) as run,
            patch.object(ide, "ensure_vscode_settings") as ensure_settings,
            patch.object(ide, "ensure_peacock_settings") as ensure_peacock,
            patch.object(ide, "launch_code", launch),
        ):
            result = ide.main()

        self.assertEqual(result, 0)
        run.assert_called_once_with(["project_picker", "--project"])
        ensure_settings.assert_called_once_with(Path("/repos/example"))
        ensure_peacock.assert_called_once_with(Path("/repos/example"))
        launch.assert_called_once_with(
            ["code-cli", "--new-window", "/repos/example"],
            {},
        )

    def test_ensure_peacock_settings_applies_auto_color(self) -> None:
        target = Path("/repos/example/trunk")
        command = [
            "apply_peacock_color",
            "apply",
            "auto",
            str(target),
            "--yes",
            "--preserve-existing",
        ]
        completed = sp.CompletedProcess(
            args=command, returncode=0, stdout="", stderr=""
        )

        with (
            patch.object(
                ide, "find_peacock_command", return_value="apply_peacock_color"
            ),
            patch.object(ide.sp, "run", return_value=completed) as run,
        ):
            ide.ensure_peacock_settings(target)

        run.assert_called_once_with(
            command,
            check=False,
            text=True,
            stdout=sp.PIPE,
            stderr=sp.PIPE,
            timeout=ide.CLI_LAUNCH_TIMEOUT_SECONDS,
        )

    def test_peacock_failure_does_not_block_vscode(self) -> None:
        picker_result = sp.CompletedProcess(
            args=["project_picker"],
            returncode=0,
            stdout="/repos/example/trunk\n",
            stderr="",
        )
        with (
            patch.object(
                ide, "parse_args", return_value=ide.CliArgs((), False, False, False)
            ),
            patch.object(ide, "find_code_command", return_value=["code-cli"]),
            patch.object(ide, "clean_vscode_env", return_value={}),
            patch.object(ide, "find_project_picker", return_value="project_picker"),
            patch.object(ide, "run", return_value=picker_result),
            patch.object(ide, "ensure_vscode_settings"),
            patch.object(
                ide,
                "ensure_peacock_settings",
                side_effect=ide.ReadinessError("Peacock color setup failed"),
            ),
            patch.object(ide, "launch_code", return_value=0) as launch,
        ):
            with contextlib.redirect_stderr(io.StringIO()) as warnings:
                ide.ensure_workspace_settings(Path("/repos/example/trunk"))
                self.assertEqual(ide.main(), 0)

        launch.assert_called_once()
        self.assertIn("Peacock color setup failed", warnings.getvalue())

    def test_no_picker_without_paths_launches_bare_vscode(self) -> None:
        launch = Mock(return_value=0)

        with (
            patch.object(
                ide,
                "parse_args",
                return_value=ide.CliArgs((), False, False, True),
            ),
            patch.object(ide, "find_code_command", return_value=["code-cli"]),
            patch.object(ide, "clean_vscode_env", return_value={}),
            patch.object(
                ide,
                "find_project_picker",
                side_effect=AssertionError("picker must not be used"),
            ),
            patch.object(ide, "launch_code", launch),
        ):
            result = ide.main()

        self.assertEqual(result, 0)
        launch.assert_called_once_with(["code-cli"], {})

    def test_directory_receives_repo_color_for_all_routes(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory) / "example"
            (root / "worktree.git").mkdir(parents=True)
            target = root / "trunk"
            target.mkdir()
            sp.run(["git", "init", "--quiet", str(target)], check=True)
            for route in ("path", "no-picker"):
                with (
                    self.subTest(route=route),
                    patch.object(
                        ide,
                        "parse_args",
                        return_value=ide.CliArgs(
                            () if route == "picker" else (str(target),),
                            False,
                            False,
                            route == "no-picker",
                        ),
                    ),
                    patch.object(ide, "find_code_command", return_value=["code-cli"]),
                    patch.object(ide, "launch_code", return_value=0),
                    patch.object(
                        ide, "find_project_picker", return_value="project_picker"
                    ),
                    patch.object(
                        ide,
                        "run",
                        return_value=sp.CompletedProcess([], 0, str(target), ""),
                    ),
                ):
                    self.assertEqual(ide.main(), 0)
                    self.assertFalse((target / ".vscode/settings.json").exists())
                    settings = json.loads((root / ".vscode/settings.json").read_text())
                    self.assertEqual(settings["window.title"], "example")
                    self.assertIn("peacock.color", settings)

    def test_direct_dry_run_and_cli_option_values_do_not_write_settings(self) -> None:
        with TemporaryDirectory() as directory:
            target = Path(directory)
            for query, dry_run in (
                ((str(target),), True),
                (("--user-data-dir", str(target)), False),
            ):
                with (
                    self.subTest(query=query),
                    patch.object(
                        ide,
                        "parse_args",
                        return_value=ide.CliArgs(query, dry_run, False, False),
                    ),
                    patch.object(ide, "find_code_command", return_value=["code-cli"]),
                    patch.object(ide, "launch_code", return_value=0),
                    contextlib.redirect_stdout(io.StringIO()),
                ):
                    self.assertEqual(ide.main(), 0)
                    self.assertFalse((target / ".vscode").exists())

    def test_explicit_path_bypasses_picker(self) -> None:
        launch = Mock(return_value=0)
        target = Path.cwd()

        with (
            patch.object(
                ide,
                "parse_args",
                return_value=ide.CliArgs((str(target),), False, False, False),
            ),
            patch.object(ide, "find_code_command", return_value=["code-cli"]),
            patch.object(ide, "clean_vscode_env", return_value={}),
            patch.object(
                ide,
                "find_project_picker",
                side_effect=AssertionError("picker must not be used"),
            ),
            patch.object(ide, "launch_code", launch),
            patch.object(ide, "ensure_workspace_settings"),
        ):
            result = ide.main()

        self.assertEqual(result, 0)
        launch.assert_called_once_with(
            ["code-cli", "--new-window", str(target.parent)],
            {},
        )


if __name__ == "__main__":
    unittest.main()
