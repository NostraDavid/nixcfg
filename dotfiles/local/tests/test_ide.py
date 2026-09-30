from __future__ import annotations

import contextlib
import importlib.util
import io
import subprocess as sp
import sys
import unittest
from pathlib import Path
from types import ModuleType
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).resolve().parents[1] / ".local/bin/ide.py"


def load_ide() -> ModuleType:
    spec = importlib.util.spec_from_file_location("ide_under_test", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


ide = load_ide()


class IdeRoutingTests(unittest.TestCase):
    def test_empty_invocation_selects_worktree(self) -> None:
        picker_result = sp.CompletedProcess(
            args=["project_picker"],
            returncode=0,
            stdout="/repos/example/trunk\n",
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
        run.assert_called_once_with(["project_picker"])
        ensure_settings.assert_called_once_with(Path("/repos/example/trunk"))
        ensure_peacock.assert_called_once_with(Path("/repos/example/trunk"))
        launch.assert_called_once_with(
            ["code-cli", "--new-window", "/repos/example/trunk"],
            {},
        )

    def test_ensure_peacock_settings_applies_auto_color(self) -> None:
        target = Path("/repos/example/trunk")
        command = ["apply_peacock_color", "apply", "auto", str(target), "--yes"]
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
        ):
            result = ide.main()

        self.assertEqual(result, 0)
        launch.assert_called_once_with(
            ["code-cli", "--new-window", str(target)],
            {},
        )


if __name__ == "__main__":
    unittest.main()
