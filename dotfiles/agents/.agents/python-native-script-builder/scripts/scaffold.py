#!/usr/bin/env python3

"""Scaffold a dependency-free one-file Python CLI."""

from __future__ import annotations

import argparse
import ast
import contextlib
import io
import logging as lg
import re
import sys
import tempfile
import unittest as ut
from collections.abc import Sequence
from pathlib import Path

MINIMUM_PYTHON = (3, 11)
COMMAND_RE = re.compile(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*")
logger = lg.getLogger(__name__)

BASE_TEMPLATE = '''\
#!/usr/bin/env python3

"""Provide a concise description of this command-line tool."""

from __future__ import annotations

import argparse
import contextlib
import io
import logging as lg
import sys
import time as tm
import unittest as ut
from collections.abc import Sequence

MINIMUM_PYTHON = (3, 11)
logger = lg.getLogger(__name__)


class InputError(Exception):
    """Report invalid domain input supplied to the command."""


def runtime_error() -> str | None:
    """Return a diagnostic when the interpreter is too old."""
    if sys.version_info < MINIMUM_PYTHON:
        required = ".".join(str(part) for part in MINIMUM_PYTHON)
        return f"Python {required} or newer is required"
    return None


def configure_logging() -> None:
    """Send human-readable operational logs to stderr."""
    handler = lg.StreamHandler(sys.stderr)
    formatter = lg.Formatter(
        fmt="%(asctime)sZ %(levelname)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )
    formatter.converter = tm.gmtime
    handler.setFormatter(formatter)
    logger.handlers.clear()
    logger.addHandler(handler)
    logger.setLevel(lg.INFO)
    logger.propagate = False


def build_message(name: str) -> str:
    """Build the example result while enforcing its domain invariant."""
    cleaned_name = name.strip()
    if not cleaned_name:
        raise InputError("name must not be empty")
    return f"Hello, {cleaned_name}!"


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser without business side effects."""
    parser = argparse.ArgumentParser(description="Run this tool's commands.")
    commands = parser.add_subparsers(dest="command", required=True)

    task_parser = commands.add_parser(
        "__COMMAND_NAME__",
        help="Run the example task.",
    )
    task_parser.add_argument(
        "--name",
        default="world",
        help="Name to greet (default: %(default)s).",
    )
    commands.add_parser("check", help="Verify runtime setup readiness.")
    commands.add_parser("unit-test", help="Run embedded unit tests.")
    return parser


def run_task(name: str) -> int:
    """Run the example task at the imperative boundary."""
    try:
        message = build_message(name)
    except InputError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    logger.info("task_completed name=%r", name.strip())
    print(message)
    return 0


def run_check() -> int:
    """Verify that this tool's runtime setup is ready."""
    error = runtime_error()
    if error is not None:
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
    if arguments.command == "__COMMAND_NAME__":
        return run_task(arguments.name)
    if arguments.command == "check":
        return run_check()
    if arguments.command == "unit-test":
        return run_unit_tests()
    raise AssertionError(f"unhandled command: {arguments.command}")


class ScriptTests(ut.TestCase):
    def test_build_message(self) -> None:
        self.assertEqual(build_message(" Codex "), "Hello, Codex!")

    def test_build_message_rejects_empty_name(self) -> None:
        with self.assertRaisesRegex(InputError, "name must not be empty"):
            build_message("   ")

    def test_help_lists_stable_commands(self) -> None:
        help_text = build_parser().format_help()
        self.assertIn("__COMMAND_NAME__", help_text)
        self.assertIn("check", help_text)
        self.assertIn("unit-test", help_text)

    def test_check_reports_exact_readiness_output(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            result = main(["check"])
        self.assertEqual(result, 0)
        self.assertEqual(stdout.getvalue(), "ok\\n")

    def test_task_separates_output_and_logs(self) -> None:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with (
            contextlib.redirect_stdout(stdout),
            contextlib.redirect_stderr(stderr),
        ):
            result = main(["__COMMAND_NAME__", "--name", "Codex"])
        self.assertEqual(result, 0)
        self.assertEqual(stdout.getvalue(), "Hello, Codex!\\n")
        self.assertIn("task_completed", stderr.getvalue())


if __name__ == "__main__":
    raise SystemExit(main())
'''


class ScaffoldError(Exception):
    """Report a failure that prevents scaffolding a complete script."""


def runtime_error() -> str | None:
    """Return a diagnostic when the interpreter is too old."""
    if sys.version_info < MINIMUM_PYTHON:
        required = ".".join(str(part) for part in MINIMUM_PYTHON)
        return f"Python {required} or newer is required"
    return None


def configure_logging() -> None:
    """Send human-readable operational logs to stderr."""
    handler = lg.StreamHandler(sys.stderr)
    handler.setFormatter(lg.Formatter("%(levelname)s %(message)s"))
    logger.handlers.clear()
    logger.addHandler(handler)
    logger.setLevel(lg.INFO)
    logger.propagate = False


def validate_inputs(output: Path, command_name: str) -> None:
    """Validate scaffold inputs without changing the filesystem."""
    error = runtime_error()
    if error is not None:
        raise ScaffoldError(error)
    if output.suffix != ".py":
        raise ScaffoldError("output must have a .py suffix")
    if output.exists():
        raise ScaffoldError(f"output already exists: {output}")
    if not COMMAND_RE.fullmatch(command_name):
        raise ScaffoldError(
            "command name must use lowercase hyphen-case, for example sync-repos"
        )


def render_script(command_name: str) -> str:
    """Render and syntax-check a generated script."""
    source = BASE_TEMPLATE.replace("__COMMAND_NAME__", command_name)
    ast.parse(source, filename=f"<{command_name}>", feature_version=(3, 11))
    compile(source, f"<{command_name}>", "exec")
    return source


def scaffold(output: Path, command_name: str, *, dry_run: bool) -> None:
    """Create OUTPUT or fully stage it in isolation during dry-run."""
    validate_inputs(output, command_name)
    source = render_script(command_name)

    if dry_run:
        with tempfile.TemporaryDirectory(prefix="python-native-scaffold-") as directory:
            staged_output = Path(directory) / output.name
            staged_output.write_text(source, encoding="utf-8")
            staged_output.chmod(0o755)
            staged_source = staged_output.read_text(encoding="utf-8")
            ast.parse(staged_source, filename=str(output), feature_version=(3, 11))
            compile(staged_source, str(output), "exec")
        return

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(source, encoding="utf-8")
    output.chmod(0o755)


def build_parser() -> argparse.ArgumentParser:
    """Build the scaffolder parser."""
    parser = argparse.ArgumentParser(
        description="Create dependency-free native Python CLI scripts."
    )
    commands = parser.add_subparsers(dest="command", required=True)
    create_parser = commands.add_parser("create", help="Create a new script.")
    create_parser.add_argument("output", type=Path, help="New .py file to create.")
    create_parser.add_argument(
        "--command-name",
        required=True,
        help="Visible task command in lowercase hyphen-case.",
    )
    create_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Stage and validate temporarily without creating OUTPUT.",
    )
    commands.add_parser("check", help="Verify scaffolder runtime readiness.")
    commands.add_parser("unit-test", help="Run embedded unit tests.")
    return parser


def run_create(output: Path, command_name: str, *, dry_run: bool) -> int:
    """Run the create command and translate expected failures."""
    try:
        scaffold(output, command_name, dry_run=dry_run)
    except ScaffoldError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    if dry_run:
        logger.info(
            "script_creation_planned output=%r command_name=%r",
            str(output),
            command_name,
        )
        print(f"Dry run succeeded; would create executable {output}.")
        return 0
    logger.info(
        "script_created output=%r command_name=%r",
        str(output),
        command_name,
    )
    print(f"Created dependency-free executable {output}.")
    return 0


def run_check() -> int:
    """Verify that the scaffolder's runtime setup is ready."""
    error = runtime_error()
    if error is not None:
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
    if arguments.command == "create":
        return run_create(
            arguments.output,
            arguments.command_name,
            dry_run=arguments.dry_run,
        )
    if arguments.command == "check":
        return run_check()
    if arguments.command == "unit-test":
        return run_unit_tests()
    raise AssertionError(f"unhandled command: {arguments.command}")


class ScaffoldTests(ut.TestCase):
    def test_rendered_script_uses_only_native_runtime_metadata(self) -> None:
        source = render_script("sync-repos")
        self.assertTrue(source.startswith("#!/usr/bin/env python3\n"))
        self.assertNotIn("# /// script", source)
        self.assertNotIn("uv ", source)
        self.assertIn("from __future__ import annotations", source)
        self.assertIn('commands.add_parser("check"', source)
        self.assertIn('commands.add_parser("unit-test"', source)

    def test_validate_inputs_rejects_invalid_values(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ScaffoldError, ".py suffix"):
                validate_inputs(root / "tool.txt", "run")
            with self.assertRaisesRegex(ScaffoldError, "lowercase hyphen-case"):
                validate_inputs(root / "tool.py", "Not Valid")

    def test_scaffold_creates_executable_script(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "nested" / "tool.py"
            scaffold(output, "sync-repos", dry_run=False)
            self.assertTrue(output.is_file())
            self.assertNotEqual(output.stat().st_mode & 0o111, 0)

    def test_scaffold_dry_run_leaves_no_target_or_parent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "nested" / "tool.py"
            scaffold(output, "sync-repos", dry_run=True)
            self.assertFalse(output.exists())
            self.assertFalse(output.parent.exists())

    def test_help_lists_stable_commands(self) -> None:
        help_text = build_parser().format_help()
        self.assertIn("create", help_text)
        self.assertIn("check", help_text)
        self.assertIn("unit-test", help_text)

    def test_check_reports_exact_readiness_output(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            result = main(["check"])
        self.assertEqual(result, 0)
        self.assertEqual(stdout.getvalue(), "ok\n")

    def test_create_dry_run_reports_plan_without_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "tool.py"
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                result = main(
                    [
                        "create",
                        str(output),
                        "--command-name",
                        "sync-repos",
                        "--dry-run",
                    ]
                )
            self.assertEqual(result, 0)
            self.assertIn("Dry run succeeded", stdout.getvalue())
            self.assertFalse(output.exists())


if __name__ == "__main__":
    raise SystemExit(main())
