#!/usr/bin/env python3

"""Validate dependency-free one-file Python CLIs."""

from __future__ import annotations

import argparse
import ast
import contextlib
import io
import json
import logging as lg
import os
import subprocess as sp
import sys
import tempfile
import unittest as ut
import unittest.mock as mock
from collections.abc import Sequence
from pathlib import Path

MINIMUM_PYTHON = (3, 11)
SHEBANG = "#!/usr/bin/env python3"
IMPORT_POLICY_PATH = (
    Path(__file__).resolve().parent.parent / "references" / "import-policy.json"
)
QUALITY_CHECK_TIMEOUT_SECONDS = 120
logger = lg.getLogger(__name__)


class ValidationError(Exception):
    """Report invalid validation configuration or source structure."""


def runtime_error() -> str | None:
    """Return a diagnostic when the interpreter is too old."""
    if sys.version_info < MINIMUM_PYTHON:
        required = ".".join(str(part) for part in MINIMUM_PYTHON)
        return f"Python {required} or newer is required"
    return None


def configure_logging() -> None:
    """Send validator diagnostics to stderr."""
    handler = lg.StreamHandler(sys.stderr)
    handler.setFormatter(lg.Formatter("%(levelname)s %(message)s"))
    logger.handlers.clear()
    logger.addHandler(handler)
    logger.setLevel(lg.INFO)
    logger.propagate = False


def load_alias_policy() -> dict[str, frozenset[str]]:
    """Load and validate the canonical standard-library alias registry."""
    try:
        document = json.loads(IMPORT_POLICY_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValidationError(f"cannot load import policy: {error}") from error

    if not isinstance(document, dict):
        raise ValidationError("import policy must be a JSON object")
    raw_aliases = document.get("aliases")
    if not isinstance(raw_aliases, dict):
        raise ValidationError("import policy must contain an aliases table")
    aliases: dict[str, frozenset[str]] = {}
    for module, values in raw_aliases.items():
        if not isinstance(module, str) or not isinstance(values, list):
            raise ValidationError("import policy aliases must be string lists")
        if not values or not all(isinstance(value, str) for value in values):
            raise ValidationError(
                "import policy aliases must be non-empty string lists"
            )
        aliases[module] = frozenset(values)
    return aliases


def qualified_name(node: ast.expr) -> str | None:
    """Return a dotted name for a simple expression."""
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        owner = qualified_name(node.value)
        if owner is not None:
            return f"{owner}.{node.attr}"
    return None


def expected_import(module: str, aliases: frozenset[str]) -> str:
    """Describe the allowed import forms for MODULE."""
    return " or ".join(f"import {module} as {alias}" for alias in sorted(aliases))


def is_standard_library(module: str) -> bool:
    """Check the interpreter's authoritative standard-library module set."""
    return module.split(".", maxsplit=1)[0] in sys.stdlib_module_names | {"__future__"}


def inspect_imports(
    tree: ast.Module,
    policy: dict[str, frozenset[str]],
) -> list[str]:
    """Reject third-party imports and enforce registered aliases."""
    errors: list[str] = []
    imported_forms: set[tuple[str, str | None]] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and qualified_name(node.func) in {
            "__import__",
            "importlib.import_module",
        }:
            errors.append(f"line {node.lineno}: dynamic imports are not allowed")
            continue
        if isinstance(node, ast.Import):
            for imported in node.names:
                imported_forms.add((imported.name, imported.asname))
                if not is_standard_library(imported.name):
                    errors.append(
                        f"line {node.lineno}: third-party or local import is not "
                        f"allowed: {imported.name}"
                    )
                    continue
                aliases = policy.get(imported.name)
                if aliases is not None and imported.asname not in aliases:
                    errors.append(
                        f"line {node.lineno}: import {imported.name} must use "
                        f"one of these forms: {expected_import(imported.name, aliases)}"
                    )
            continue

        if not isinstance(node, ast.ImportFrom):
            continue
        if node.level != 0 or node.module is None:
            errors.append(f"line {node.lineno}: relative imports are not allowed")
            continue
        if not is_standard_library(node.module):
            errors.append(
                f"line {node.lineno}: third-party or local import is not allowed: "
                f"{node.module}"
            )
            continue
        aliases = policy.get(node.module)
        if aliases is not None:
            errors.append(
                f"line {node.lineno}: do not import from {node.module}; use "
                f"{expected_import(node.module, aliases)}"
            )

    required_imports = {
        ("argparse", None): "missing import argparse",
        ("logging", "lg"): "missing import logging as lg",
        ("unittest", "ut"): "missing import unittest as ut",
    }
    for imported_form, error in required_imports.items():
        if imported_form not in imported_forms:
            errors.append(error)
    return errors


def inspect_minimum_python(tree: ast.Module) -> list[str]:
    """Require the native runtime version contract."""
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name) or target.id != "MINIMUM_PYTHON":
            continue
        if not isinstance(node.value, ast.Tuple):
            break
        values = tuple(
            element.value
            for element in node.value.elts
            if isinstance(element, ast.Constant) and isinstance(element.value, int)
        )
        if values == MINIMUM_PYTHON and len(values) == len(node.value.elts):
            return []
        break
    return ["MINIMUM_PYTHON must be exactly (3, 11)"]


def inspect_future_annotations(tree: ast.Module) -> list[str]:
    """Require postponed annotations for the supported Python range."""
    for node in tree.body:
        if not isinstance(node, ast.ImportFrom) or node.module != "__future__":
            continue
        if any(imported.name == "annotations" for imported in node.names):
            return []
    return ["missing from __future__ import annotations"]


def inspect_cli_structure(tree: ast.Module) -> list[str]:
    """Require argparse subcommands for tasks, readiness, and tests."""
    errors: list[str] = []
    command_names: set[str] = set()
    has_required_subparsers = False
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if qualified_name(node.func) is not None and qualified_name(node.func).endswith(
            ".add_subparsers"
        ):
            has_required_subparsers = any(
                keyword.arg == "required"
                and isinstance(keyword.value, ast.Constant)
                and keyword.value.value is True
                for keyword in node.keywords
            )
        if (
            qualified_name(node.func) is not None
            and qualified_name(node.func).endswith(".add_parser")
            and node.args
            and isinstance(node.args[0], ast.Constant)
            and isinstance(node.args[0].value, str)
        ):
            command_names.add(node.args[0].value)

    if not has_required_subparsers:
        errors.append("argparse subparsers must use required=True")
    if "test" in command_names:
        errors.append('subcommand "test" is ambiguous; use "unit-test"')
    if "check" not in command_names:
        errors.append('missing a visible subcommand named "check"')
    if "unit-test" not in command_names:
        errors.append('missing a visible subcommand named "unit-test"')
    task_commands = command_names - {"check", "unit-test", "test"}
    if not task_commands:
        errors.append("missing a visible task subcommand")
    return errors


def inspect_logging(tree: ast.Module) -> list[str]:
    """Require one stdlib logger and a stderr handler."""
    has_logger = False
    has_stderr_handler = False
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if (
            qualified_name(node.func) == "lg.getLogger"
            and len(node.args) == 1
            and isinstance(node.args[0], ast.Name)
            and node.args[0].id == "__name__"
        ):
            has_logger = True
        if (
            qualified_name(node.func) == "lg.StreamHandler"
            and len(node.args) == 1
            and qualified_name(node.args[0]) == "sys.stderr"
        ):
            has_stderr_handler = True
    errors = []
    if not has_logger:
        errors.append("missing logger = lg.getLogger(__name__)")
    if not has_stderr_handler:
        errors.append("logging must use lg.StreamHandler(sys.stderr)")
    return errors


def inspect_subprocess_safety(tree: ast.Module) -> list[str]:
    """Require argument vectors, timeouts, and shell-free subprocesses."""
    errors: list[str] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        function = qualified_name(node.func)
        if function not in {"sp.run", "sp.call", "sp.check_call", "sp.check_output"}:
            continue
        if any(
            keyword.arg == "shell"
            and isinstance(keyword.value, ast.Constant)
            and keyword.value.value is True
            for keyword in node.keywords
        ):
            errors.append(
                f"line {node.lineno}: subprocess calls must not use shell=True"
            )
        if not any(keyword.arg == "timeout" for keyword in node.keywords):
            errors.append(f"line {node.lineno}: subprocess calls must set a timeout")
        if (
            node.args
            and isinstance(node.args[0], ast.Constant)
            and isinstance(node.args[0].value, str)
        ):
            errors.append(
                f"line {node.lineno}: subprocess commands must use an argument vector"
            )
    return errors


def structural_errors(target: Path) -> list[str]:
    """Return every statically observable native-script violation."""
    errors: list[str] = []
    if not target.is_file():
        return [f"target is not a file: {target}"]
    if target.suffix != ".py":
        errors.append("target must have a .py suffix")
    try:
        source = target.read_text(encoding="utf-8")
    except OSError as error:
        return [f"cannot read target: {error}"]
    if not os.access(target, os.X_OK):
        errors.append("target must be executable; run chmod +x TARGET")
    if not source.startswith(f"{SHEBANG}\n"):
        errors.append(f"first line must be {SHEBANG}")
    if any(line.strip() == "# /// script" for line in source.splitlines()):
        errors.append("PEP 723 metadata is not allowed in a native script")
    for lockfile in (Path(f"{target}.lock"), target.with_suffix(".lock")):
        if lockfile.exists():
            errors.append(f"native script lockfile must not exist: {lockfile}")

    try:
        tree = ast.parse(source, filename=str(target), feature_version=(3, 11))
    except SyntaxError as error:
        errors.append(f"invalid Python syntax: {error}")
        return errors
    try:
        policy = load_alias_policy()
    except ValidationError as error:
        errors.append(str(error))
    else:
        errors.extend(inspect_imports(tree, policy))
    errors.extend(inspect_minimum_python(tree))
    errors.extend(inspect_future_annotations(tree))
    errors.extend(inspect_cli_structure(tree))
    errors.extend(inspect_logging(tree))
    errors.extend(inspect_subprocess_safety(tree))
    return errors


def run_process(command: Sequence[str], *, expected_stdout: str | None = None) -> bool:
    """Run one quality command in a clean Python import environment."""
    logger.info("quality_check_started command=%r", list(command))
    environment = os.environ.copy()
    environment.pop("PYTHONPATH", None)
    environment.pop("VIRTUAL_ENV", None)
    try:
        if expected_stdout is None:
            process = sp.run(
                command,
                check=False,
                env=environment,
                timeout=QUALITY_CHECK_TIMEOUT_SECONDS,
            )
        else:
            process = sp.run(
                command,
                check=False,
                env=environment,
                stdout=sp.PIPE,
                text=True,
                timeout=QUALITY_CHECK_TIMEOUT_SECONDS,
            )
    except FileNotFoundError as error:
        logger.error("quality_command_not_found command=%r", error.filename)
        return False
    except sp.TimeoutExpired:
        logger.error("quality_check_timed_out command=%r", list(command))
        return False
    if process.returncode != 0:
        logger.error(
            "quality_check_failed command=%r returncode=%d",
            list(command),
            process.returncode,
        )
        return False
    if expected_stdout is not None and process.stdout != expected_stdout:
        logger.error(
            "quality_check_unexpected_stdout command=%r expected=%r actual=%r",
            list(command),
            expected_stdout,
            process.stdout,
        )
        return False
    return True


def quality_commands(target: Path) -> list[list[str]]:
    """Build the dependency-free executable quality gate list."""
    executable = str(target.resolve())
    return [
        [executable, "--help"],
        [executable, "check"],
        [executable, "unit-test"],
    ]


def validate_target(target: Path, *, structural_only: bool) -> list[str]:
    """Run structural and, unless disabled, executable quality gates."""
    errors = structural_errors(target)
    if errors or structural_only:
        return errors
    readiness_command = [str(target.resolve()), "check"]
    for command in quality_commands(target):
        expected_stdout = "ok\n" if command == readiness_command else None
        if not run_process(command, expected_stdout=expected_stdout):
            errors.append(f"quality check failed: {' '.join(command)}")
    return errors


def build_parser() -> argparse.ArgumentParser:
    """Build the validator parser."""
    parser = argparse.ArgumentParser(
        description="Validate dependency-free native Python CLI scripts."
    )
    commands = parser.add_subparsers(dest="command", required=True)
    validate_parser = commands.add_parser("validate", help="Validate one script.")
    validate_parser.add_argument("target", type=Path, help="Script to validate.")
    validate_parser.add_argument(
        "--structural-only",
        action="store_true",
        help="Skip executable help, readiness, and embedded unit-test gates.",
    )
    commands.add_parser("check", help="Verify validator runtime readiness.")
    commands.add_parser("unit-test", help="Run embedded unit tests.")
    return parser


def run_validate(target: Path, *, structural_only: bool) -> int:
    """Run validation and translate failures into CLI diagnostics."""
    errors = validate_target(target, structural_only=structural_only)
    if errors:
        for error in errors:
            logger.error("validation_error target=%r reason=%r", str(target), error)
        print(f"Error: validation failed with {len(errors)} error(s)", file=sys.stderr)
        return 1
    logger.info(
        "validation_passed target=%r structural_only=%r",
        str(target),
        structural_only,
    )
    if structural_only:
        print("Structural validation passed.")
    else:
        print("All native quality gates passed.")
    return 0


def run_check() -> int:
    """Verify that the validator's runtime setup is ready."""
    error = runtime_error()
    if error is not None:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    try:
        load_alias_policy()
    except ValidationError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    print("ok")
    return 0


def run_unit_tests() -> int:
    """Run tests from this file without external test dependencies."""
    suite = ut.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = ut.TextTestRunner(stream=sys.stdout, verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


def main(argv: Sequence[str] | None = None) -> int:
    """Parse arguments and dispatch one command."""
    error = runtime_error()
    if error is not None:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    arguments = build_parser().parse_args(list(argv) if argv is not None else None)
    configure_logging()
    if arguments.command == "validate":
        return run_validate(
            arguments.target,
            structural_only=arguments.structural_only,
        )
    if arguments.command == "check":
        return run_check()
    if arguments.command == "unit-test":
        return run_unit_tests()
    raise AssertionError(f"unhandled command: {arguments.command}")


def valid_script_source(extra_import: str = "", extra_source: str = "") -> str:
    """Return a compact structurally valid source fixture."""
    optional_import = f"{extra_import}\n" if extra_import else ""
    return f"""{SHEBANG}

from __future__ import annotations

import argparse
import logging as lg
import sys
import unittest as ut
from collections.abc import Sequence
{optional_import}
MINIMUM_PYTHON = (3, 11)
logger = lg.getLogger(__name__)

def configure_logging() -> None:
    logger.addHandler(lg.StreamHandler(sys.stderr))

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("run")
    commands.add_parser("check")
    commands.add_parser("unit-test")
    return parser

def main(argv: Sequence[str] | None = None) -> int:
    arguments = build_parser().parse_args(list(argv) if argv is not None else None)
    if arguments.command == "check":
        print("ok")
    return 0

{extra_source}
if __name__ == "__main__":
    raise SystemExit(main())
"""


class ValidatorTests(ut.TestCase):
    def test_load_alias_policy_contains_native_aliases(self) -> None:
        policy = load_alias_policy()
        self.assertEqual(policy["logging"], frozenset({"lg"}))
        self.assertEqual(policy["unittest"], frozenset({"ut"}))

    def test_structural_errors_accepts_valid_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "tool.py"
            target.write_text(valid_script_source(), encoding="utf-8")
            target.chmod(0o755)
            self.assertEqual(structural_errors(target), [])

    def test_structural_errors_rejects_third_party_import(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "tool.py"
            target.write_text(
                valid_script_source("import requests"),
                encoding="utf-8",
            )
            target.chmod(0o755)
            errors = structural_errors(target)
            self.assertTrue(any("third-party" in error for error in errors))

    def test_structural_errors_rejects_dynamic_import(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "tool.py"
            target.write_text(
                valid_script_source(extra_source='plugin = __import__("json")'),
                encoding="utf-8",
            )
            target.chmod(0o755)
            errors = structural_errors(target)
            self.assertTrue(any("dynamic imports" in error for error in errors))

    def test_structural_errors_requires_stable_subcommands(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "tool.py"
            source = valid_script_source().replace(
                'commands.add_parser("check")',
                'commands.add_parser("test")',
            )
            target.write_text(source, encoding="utf-8")
            target.chmod(0o755)
            errors = structural_errors(target)
            self.assertIn('missing a visible subcommand named "check"', errors)
            self.assertTrue(any("ambiguous" in error for error in errors))

    def test_structural_errors_requires_future_annotations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "tool.py"
            source = valid_script_source().replace(
                "from __future__ import annotations\n",
                "",
            )
            target.write_text(source, encoding="utf-8")
            target.chmod(0o755)
            self.assertIn(
                "missing from __future__ import annotations",
                structural_errors(target),
            )

    def test_structural_errors_rejects_pep_723_and_lockfiles(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "tool.py"
            source = valid_script_source().replace(
                f"{SHEBANG}\n",
                f"{SHEBANG}\n# /// script\n# ///\n",
            )
            target.write_text(source, encoding="utf-8")
            target.chmod(0o755)
            Path(f"{target}.lock").write_text("locked", encoding="utf-8")
            errors = structural_errors(target)
            self.assertTrue(any("PEP 723" in error for error in errors))
            self.assertTrue(any("lockfile" in error for error in errors))

    def test_subprocess_safety_requires_vector_timeout_and_no_shell(self) -> None:
        tree = ast.parse(
            """
import subprocess as sp
sp.run("echo unsafe", shell=True)
"""
        )
        errors = inspect_subprocess_safety(tree)
        self.assertTrue(any("shell=True" in error for error in errors))
        self.assertTrue(any("timeout" in error for error in errors))
        self.assertTrue(any("argument vector" in error for error in errors))

    def test_quality_commands_cover_public_contract(self) -> None:
        target = Path("tool.py")
        self.assertEqual(
            quality_commands(target),
            [
                [str(target.resolve()), "--help"],
                [str(target.resolve()), "check"],
                [str(target.resolve()), "unit-test"],
            ],
        )

    def test_run_process_requires_exact_stdout(self) -> None:
        completed = sp.CompletedProcess(["tool", "check"], 0, stdout="ready\n")
        with mock.patch.object(sp, "run", return_value=completed):
            self.assertFalse(run_process(["tool", "check"], expected_stdout="ok\n"))

    def test_validate_target_runs_all_executable_gates(self) -> None:
        target = Path("tool.py")
        observed: list[tuple[list[str], str | None]] = []

        def fake_run(
            command: Sequence[str],
            *,
            expected_stdout: str | None = None,
        ) -> bool:
            observed.append((list(command), expected_stdout))
            return True

        with (
            mock.patch.object(
                sys.modules[__name__], "structural_errors", return_value=[]
            ),
            mock.patch.object(
                sys.modules[__name__], "run_process", side_effect=fake_run
            ),
        ):
            self.assertEqual(validate_target(target, structural_only=False), [])
        self.assertEqual(len(observed), 3)
        self.assertEqual(observed[1][1], "ok\n")

    def test_check_reports_exact_readiness_output(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            result = main(["check"])
        self.assertEqual(result, 0)
        self.assertEqual(stdout.getvalue(), "ok\n")


if __name__ == "__main__":
    raise SystemExit(main())
