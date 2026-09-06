#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "pydantic==2.13.4",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""Validate structure and quality gates for an opinionated one-file Python CLI."""

import ast
import contextlib
import io
import os
import re
import shutil
import subprocess as sp
import sys
import tempfile
from collections.abc import Sequence
from pathlib import Path

import click
import pytest
import structlog as sl
import structlog.stdlib as log
import tomllib
from click.testing import CliRunner
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    TypeAdapter,
    ValidationError as PydanticValidationError,
)

SHEBANG = "#!/usr/bin/env -S uv run --script"
IMPORT_POLICY_PATH = (
    Path(__file__).resolve().parent.parent / "references" / "import-policy.toml"
)
REQUIRED_DEPENDENCIES = frozenset({"click", "pytest", "pytest-cov", "structlog"})
QUALITY_CHECK_TIMEOUT_SECONDS = 300
SCRIPT_BLOCK_RE = re.compile(
    r"^# /// script\s*$\n(?P<body>(?:^#.*$\n)*?)^# ///\s*$",
    re.MULTILINE,
)
EXACT_DEPENDENCY_RE = re.compile(
    r"^(?P<name>[A-Za-z0-9][A-Za-z0-9._-]*)==(?P<version>[^;\s]+)$"
)
logger = log.get_logger(__name__)


class Pep723Document(BaseModel):
    """Validate the PEP 723 fields consumed by this tool."""

    model_config = ConfigDict(extra="ignore", frozen=True)

    requires_python: str = Field(alias="requires-python")
    dependencies: tuple[str, ...]


class ScriptMetadata(BaseModel):
    """Hold normalized script metadata used by quality checks."""

    model_config = ConfigDict(frozen=True)

    dependencies: tuple[str, ...]
    dependency_names: frozenset[str]
    requires_python: str


class ValidationError(Exception):
    """Report invalid script metadata that cannot be inspected further."""


def configure_logging() -> None:
    """Send human-readable structured logs to stderr."""
    sl.configure(
        processors=[
            sl.processors.TimeStamper(fmt="iso", utc=True),
            sl.processors.add_log_level,
            sl.dev.ConsoleRenderer(colors=sys.stderr.isatty()),
        ],
        wrapper_class=sl.make_filtering_bound_logger("debug"),
        logger_factory=sl.PrintLoggerFactory(file=sys.stderr),
        cache_logger_on_first_use=False,
    )


def load_alias_policy() -> dict[str, frozenset[str]]:
    try:
        document = tomllib.loads(IMPORT_POLICY_PATH.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise ValidationError(f"cannot load import policy: {error}") from error

    raw_aliases = document.get("aliases")
    if raw_aliases is None:
        raise ValidationError("import policy must contain an aliases table")
    try:
        aliases = TypeAdapter(dict[str, list[str]]).validate_python(raw_aliases)
    except PydanticValidationError as error:
        raise ValidationError("import policy aliases must be string lists") from error
    return {module: frozenset(values) for module, values in aliases.items()}


def extract_metadata(source: str) -> ScriptMetadata:
    match = SCRIPT_BLOCK_RE.search(source)
    if match is None:
        raise ValidationError("missing a valid PEP 723 script metadata block")

    body = "\n".join(
        line.removeprefix("# ").removeprefix("#")
        for line in match.group("body").splitlines()
    )
    try:
        raw_document = tomllib.loads(body)
        document = Pep723Document.model_validate(raw_document)
    except (tomllib.TOMLDecodeError, PydanticValidationError) as error:
        raise ValidationError(f"invalid PEP 723 metadata: {error}") from error

    typed_dependencies = document.dependencies
    names = frozenset(
        match.group("name").lower().replace("_", "-")
        for dependency in typed_dependencies
        if (match := EXACT_DEPENDENCY_RE.fullmatch(dependency)) is not None
    )
    return ScriptMetadata(
        dependencies=typed_dependencies,
        dependency_names=names,
        requires_python=document.requires_python,
    )


def decorator_name(decorator: ast.expr) -> str | None:
    function = decorator.func if isinstance(decorator, ast.Call) else decorator
    if isinstance(function, ast.Attribute):
        return function.attr
    if isinstance(function, ast.Name):
        return function.id
    return None


def decorator_keywords(decorator: ast.expr) -> dict[str, object]:
    if not isinstance(decorator, ast.Call):
        return {}
    values: dict[str, object] = {}
    for keyword in decorator.keywords:
        if keyword.arg is not None and isinstance(keyword.value, ast.Constant):
            values[keyword.arg] = keyword.value.value
    return values


def invokes_embedded_pytest(node: ast.FunctionDef | ast.AsyncFunctionDef) -> bool:
    for candidate in ast.walk(node):
        if not (
            isinstance(candidate, ast.Call)
            and isinstance(candidate.func, ast.Attribute)
            and isinstance(candidate.func.value, ast.Name)
            and candidate.func.value.id == "pytest"
            and candidate.func.attr == "main"
            and candidate.args
        ):
            continue
        arguments = candidate.args[0]
        if not isinstance(arguments, (ast.List, ast.Tuple)):
            continue
        has_current_file = any(
            isinstance(element, ast.Name) and element.id == "__file__"
            for element in arguments.elts
        )
        literal_arguments = {
            element.value
            for element in arguments.elts
            if isinstance(element, ast.Constant) and isinstance(element.value, str)
        }
        required_arguments = {
            "-q",
            "--cov",
            "--cov-branch",
            "--cov-config",
            "--cov-report=term-missing",
            "-p",
            "no:cacheprovider",
        }
        if has_current_file and required_arguments <= literal_arguments:
            return True
    return False


def isolates_coverage_data(node: ast.FunctionDef | ast.AsyncFunctionDef) -> bool:
    has_temporary_directory = False
    has_coverage_file_override = False
    has_coverage_include_config = False
    for candidate in ast.walk(node):
        if (
            isinstance(candidate, ast.Call)
            and isinstance(candidate.func, ast.Attribute)
            and isinstance(candidate.func.value, ast.Name)
            and candidate.func.value.id == "tempfile"
            and candidate.func.attr == "TemporaryDirectory"
        ):
            has_temporary_directory = True
        if not isinstance(candidate, ast.Assign):
            if (
                isinstance(candidate, ast.Call)
                and isinstance(candidate.func, ast.Attribute)
                and candidate.func.attr == "write_text"
                and {"[run]", "patch = subprocess", "include ="}
                <= {
                    value.value
                    for value in ast.walk(candidate)
                    if isinstance(value, ast.Constant) and isinstance(value.value, str)
                }
            ):
                has_coverage_include_config = True
            continue
        for target in candidate.targets:
            if (
                isinstance(target, ast.Subscript)
                and isinstance(target.value, ast.Attribute)
                and isinstance(target.value.value, ast.Name)
                and target.value.value.id == "os"
                and target.value.attr == "environ"
                and isinstance(target.slice, ast.Constant)
                and target.slice.value == "COVERAGE_FILE"
            ):
                has_coverage_file_override = True
    return (
        has_temporary_directory
        and has_coverage_file_override
        and has_coverage_include_config
    )


def compacts_coverage_output(tree: ast.Module) -> bool:
    string_literals = {
        candidate.value
        for candidate in ast.walk(tree)
        if isinstance(candidate, ast.Constant) and isinstance(candidate.value, str)
    }
    has_stdout_redirect = any(
        isinstance(candidate, ast.Call)
        and isinstance(candidate.func, ast.Attribute)
        and candidate.func.attr == "redirect_stdout"
        and isinstance(candidate.func.value, ast.Name)
        and candidate.func.value.id == "contextlib"
        for candidate in ast.walk(tree)
    )
    return (
        has_stdout_redirect
        and {
            " tests coverage ",
            " coverage: platform ",
        }
        <= string_literals
    )


def inspect_click_structure(tree: ast.Module) -> list[str]:
    errors: list[str] = []
    has_group = False
    visible_task_commands = 0
    has_visible_check = False
    has_visible_unit_test = False

    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        for decorator in node.decorator_list:
            name = decorator_name(decorator)
            keywords = decorator_keywords(decorator)
            if name == "group":
                has_group = True
            if name != "command":
                continue

            command_name = keywords.get("name", node.name.replace("_", "-"))
            hidden = keywords.get("hidden", False) is True
            if command_name == "check":
                if hidden:
                    errors.append('Click command "check" must be visible')
                else:
                    has_visible_check = True
            elif command_name == "test":
                errors.append(
                    'Click command named "test" is ambiguous; use visible "unit-test"'
                )
            elif command_name == "unit-test":
                if hidden:
                    errors.append('Click command "unit-test" must be visible')
                else:
                    has_visible_unit_test = True
                if not invokes_embedded_pytest(node):
                    errors.append(
                        "unit-test command must run pytest for this file with "
                        "--cov, --cov-branch, --cov-config, and "
                        "--cov-report=term-missing"
                    )
                if not isolates_coverage_data(node):
                    errors.append(
                        "unit-test command must isolate COVERAGE_FILE and use a "
                        "temporary [run] include configuration for this script"
                    )
            elif not hidden:
                visible_task_commands += 1

    if not has_group:
        errors.append("missing a Click group")
    if visible_task_commands == 0:
        errors.append("missing a visible Click task command")
    if not has_visible_check:
        errors.append('missing a visible Click command named "check"')
    if not has_visible_unit_test:
        errors.append('missing a visible Click command named "unit-test"')
    elif not compacts_coverage_output(tree):
        errors.append(
            "unit-test command must suppress pytest-cov section and platform banners"
        )
    return errors


def expected_import(module: str, aliases: frozenset[str]) -> str:
    return " or ".join(f"import {module} as {alias}" for alias in sorted(aliases))


def inspect_imports(
    tree: ast.Module,
    policy: dict[str, frozenset[str]],
) -> list[str]:
    errors: list[str] = []
    has_structlog_import = False
    has_structlog_stdlib_import = False
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for imported in node.names:
                if imported.name == "structlog" and imported.asname == "sl":
                    has_structlog_import = True
                elif imported.name == "structlog.stdlib" and imported.asname == "log":
                    has_structlog_stdlib_import = True
                aliases = policy.get(imported.name)
                if aliases is not None:
                    if imported.asname not in aliases:
                        errors.append(
                            f"line {node.lineno}: import {imported.name} must use "
                            f"one of these forms: "
                            f"{expected_import(imported.name, aliases)}"
                        )
                    continue
                if imported.name.startswith("structlog."):
                    errors.append(
                        f"line {node.lineno}: use registered structlog module aliases"
                    )
            continue

        if not isinstance(node, ast.ImportFrom) or node.module is None:
            continue
        aliases = policy.get(node.module)
        if aliases is not None:
            errors.append(
                f"line {node.lineno}: do not import from {node.module}; use "
                f"{expected_import(node.module, aliases)}"
            )
            continue
        if node.module == "structlog" or node.module.startswith("structlog."):
            errors.append(
                f"line {node.lineno}: do not import structlog objects directly; "
                "use import structlog as sl or import structlog.stdlib as log"
            )
            continue

        for imported in node.names:
            module = f"{node.module}.{imported.name}"
            aliases = policy.get(module)
            if aliases is not None:
                errors.append(
                    f"line {node.lineno}: use {expected_import(module, aliases)}"
                )
    if not has_structlog_import:
        errors.append("missing import structlog as sl")
    if not has_structlog_stdlib_import:
        errors.append("missing import structlog.stdlib as log")
    return errors


def qualified_name(node: ast.expr) -> str | None:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        owner = qualified_name(node.value)
        if owner is not None:
            return f"{owner}.{node.attr}"
    return None


def inspect_structlog_logger(tree: ast.Module) -> list[str]:
    """Require the inferred stdlib logger and matching native configuration."""
    has_exact_getter = False
    exact_getter_calls: set[int] = set()
    has_matching_wrapper = False
    errors: list[str] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign) or not isinstance(node.value, ast.Call):
            continue
        if (
            len(node.targets) == 1
            and isinstance(node.targets[0], ast.Name)
            and node.targets[0].id == "logger"
            and qualified_name(node.value.func) == "log.get_logger"
            and len(node.value.args) == 1
            and isinstance(node.value.args[0], ast.Name)
            and node.value.args[0].id == "__name__"
            and not node.value.keywords
        ):
            has_exact_getter = True
            exact_getter_calls.add(id(node.value))

    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        function_name = qualified_name(node.func)
        if function_name == "log.get_logger" and id(node) not in exact_getter_calls:
            errors.append(
                f"line {node.lineno}: construct the module logger exactly as "
                "logger = log.get_logger(__name__)"
            )
        if function_name in {
            "lg.get_logger",
            "sl.get_logger",
            "sl.stdlib.get_logger",
            "structlog.get_logger",
            "structlog.stdlib.get_logger",
        }:
            errors.append(f"line {node.lineno}: use logger = log.get_logger(__name__)")
        if function_name != "sl.configure":
            continue
        for keyword in node.keywords:
            if keyword.arg != "wrapper_class" or not isinstance(
                keyword.value, ast.Call
            ):
                continue
            wrapper_call = keyword.value
            if (
                qualified_name(wrapper_call.func) == "sl.make_filtering_bound_logger"
                and len(wrapper_call.args) == 1
                and isinstance(wrapper_call.args[0], ast.Constant)
                and wrapper_call.args[0].value == "debug"
            ):
                has_matching_wrapper = True

    if not has_exact_getter:
        errors.append("missing logger = log.get_logger(__name__)")
    if not has_matching_wrapper:
        errors.append(
            "sl.configure must use "
            'wrapper_class=sl.make_filtering_bound_logger("debug")'
        )
    return errors


def inspect_subprocess_timeouts(tree: ast.Module) -> list[str]:
    errors: list[str] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or qualified_name(node.func) != "sp.run":
            continue
        if not any(keyword.arg == "timeout" for keyword in node.keywords):
            errors.append(f"line {node.lineno}: subprocess.run must set a timeout")
    return errors


def structural_errors(target: Path) -> tuple[list[str], ScriptMetadata | None]:
    errors: list[str] = []
    if not target.is_file():
        return [f"target is not a file: {target}"], None
    if target.suffix != ".py":
        errors.append("target must have a .py suffix")

    try:
        source = target.read_text(encoding="utf-8")
    except OSError as error:
        errors.append(f"cannot read target: {error}")
        return errors, None
    if not os.access(target, os.X_OK):
        errors.append("target must be executable; run chmod +x TARGET")
    if not source.startswith(f"{SHEBANG}\n"):
        errors.append(f"first line must be {SHEBANG}")

    try:
        metadata = extract_metadata(source)
    except ValidationError as error:
        errors.append(str(error))
        metadata = None

    if metadata is not None:
        if metadata.requires_python != ">=3.14":
            errors.append('requires-python must be exactly ">=3.14"')
        unpinned = [
            dependency
            for dependency in metadata.dependencies
            if EXACT_DEPENDENCY_RE.fullmatch(dependency) is None
        ]
        if unpinned:
            errors.append(f"dependencies are not exactly pinned: {', '.join(unpinned)}")
        missing = sorted(REQUIRED_DEPENDENCIES - metadata.dependency_names)
        if missing:
            errors.append(f"missing required dependencies: {', '.join(missing)}")

    if Path(f"{target}.lock").exists():
        errors.append(f"script lockfile must not exist: {target}.lock")

    try:
        tree = ast.parse(source, filename=str(target))
    except SyntaxError as error:
        errors.append(f"invalid Python syntax: {error}")
    else:
        errors.extend(inspect_click_structure(tree))
        try:
            errors.extend(inspect_imports(tree, load_alias_policy()))
        except ValidationError as error:
            errors.append(str(error))
        errors.extend(inspect_structlog_logger(tree))
        errors.extend(inspect_subprocess_timeouts(tree))
    return errors, metadata


def run_check(command: Sequence[str], *, expected_stdout: str | None = None) -> bool:
    logger.info("quality_check_started", command=list(command))
    environment = os.environ.copy()
    environment.pop("VIRTUAL_ENV", None)
    environment.pop("PYTHONPATH", None)
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
        logger.error("quality_command_not_found", command=error.filename)
        return False
    except sp.TimeoutExpired:
        logger.error(
            "quality_check_timed_out",
            command=list(command),
            timeout_seconds=QUALITY_CHECK_TIMEOUT_SECONDS,
        )
        return False
    if process.returncode != 0:
        logger.error(
            "quality_check_failed",
            command=list(command),
            returncode=process.returncode,
        )
        return False
    if expected_stdout is not None and process.stdout != expected_stdout:
        logger.error(
            "quality_check_unexpected_stdout",
            command=list(command),
            expected=expected_stdout,
            actual=process.stdout,
        )
        return False
    return True


def quality_commands(target: Path, metadata: ScriptMetadata) -> list[list[str]]:
    dependency_args = [
        argument
        for dependency in metadata.dependencies
        for argument in ("--with", dependency)
    ]
    return [
        ["uvx", "--from", "ruff", "ruff", "format", "--check", str(target)],
        ["uvx", "--from", "ruff", "ruff", "check", str(target)],
        [
            "uvx",
            "--from",
            "ty",
            *dependency_args,
            "ty",
            "check",
            "--python-version",
            "3.14",
            str(target),
        ],
        [
            "uvx",
            "--from",
            "pyrefly",
            *dependency_args,
            "pyrefly",
            "check",
            "--preset",
            "basic",
            "--python-version",
            "3.14",
            "--progress-bar",
            "no",
            str(target),
        ],
        [str(target.resolve()), "--help"],
        [str(target.resolve()), "check"],
        [str(target.resolve()), "unit-test"],
    ]


def validate_target(target: Path, *, structural_only: bool) -> list[str]:
    errors, metadata = structural_errors(target)
    if errors or structural_only:
        return errors
    if metadata is None:
        return ["metadata unavailable after validation"]

    readiness_command = [str(target.resolve()), "check"]
    failed_commands = []
    for command in quality_commands(target, metadata):
        expected_stdout = "ok\n" if command == readiness_command else None
        if not run_check(command, expected_stdout=expected_stdout):
            failed_commands.append(" ".join(command))
    return [f"quality check failed: {command}" for command in failed_commands]


@click.group()
def cli() -> None:
    """Validate one-file Python CLIs against the skill standard."""
    configure_logging()


@cli.command(name="validate")
@click.argument("target", type=click.Path(path_type=Path, dir_okay=False))
@click.option(
    "--structural-only",
    is_flag=True,
    help="Skip Ruff, ty, Pyrefly, CLI help, and embedded pytest execution.",
)
def validate_command(target: Path, *, structural_only: bool) -> None:
    """Validate TARGET and run every configured quality gate."""
    errors = validate_target(target, structural_only=structural_only)
    if errors:
        for error in errors:
            logger.error("validation_error", target=str(target), reason=error)
        raise click.ClickException(f"validation failed with {len(errors)} error(s)")

    logger.info(
        "validation_passed",
        target=str(target),
        structural_only=structural_only,
    )
    if structural_only:
        click.echo("Structural validation passed.")
    else:
        click.echo("All quality gates passed.")


@cli.command(name="check")
def check_command() -> None:
    """Verify that the validator's runtime setup is ready."""
    if shutil.which("uvx") is None:
        raise click.ClickException("uvx is required but was not found on PATH")
    try:
        load_alias_policy()
    except ValidationError as error:
        raise click.ClickException(str(error)) from error
    click.echo("ok")


def compact_pytest_output(output: str) -> str:
    """Remove pytest-cov banners while preserving its useful report."""
    lines = []
    for line in output.splitlines():
        is_section_banner = (
            line.startswith("=") and line.endswith("=") and " tests coverage " in line
        )
        is_platform_banner = (
            line.startswith("_")
            and line.endswith("_")
            and " coverage: platform " in line
        )
        if not is_section_banner and not is_platform_banner:
            lines.append(line)
    return "\n".join(lines).strip() + "\n"


@click.command(name="unit-test")
def _embedded_unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="python-cli-coverage-") as directory:
        coverage_config = Path(directory) / ".coveragerc"
        coverage_config.write_text(
            os.linesep.join(
                (
                    "[run]",
                    "patch = subprocess",
                    "include =",
                    f"    {Path(__file__).resolve().as_posix()}",
                    "",
                )
            ),
            encoding="utf-8",
        )
        previous_coverage_file = os.environ.get("COVERAGE_FILE")
        os.environ["COVERAGE_FILE"] = str(Path(directory) / ".coverage")
        pytest_output = io.StringIO()
        try:
            with contextlib.redirect_stdout(pytest_output):
                result = pytest.main(
                    [
                        "--cov",
                        "--cov-branch",
                        "--cov-config",
                        str(coverage_config),
                        "--cov-report=term-missing",
                        "-p",
                        "no:cacheprovider",
                        __file__,
                        "-q",
                    ]
                )
        finally:
            if previous_coverage_file is None:
                os.environ.pop("COVERAGE_FILE", None)
            else:
                os.environ["COVERAGE_FILE"] = previous_coverage_file
    click.echo(compact_pytest_output(pytest_output.getvalue()), nl=False)
    raise SystemExit(result)


cli.add_command(_embedded_unit_test_command)


def valid_script_source(extra_import: str = "") -> str:
    imports = f"{extra_import}\n" if extra_import else ""
    return f"""{SHEBANG}
# //__PEP_OPEN__
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

import contextlib
import io
import os
import sys
import tempfile
from pathlib import Path

import click
import pytest
import structlog as sl
import structlog.stdlib as log
{imports}
logger = log.get_logger(__name__)

def configure_logging() -> None:
    sl.configure(
        wrapper_class=sl.make_filtering_bound_logger("debug"),
    )

@click.group()
def cli() -> None:
    pass

@cli.command(name="check")
def check_command() -> None:
    click.echo("ok")

@cli.command(name="run")
def run_command() -> None:
    pass

def compact_pytest_output(output: str) -> str:
    lines = []
    for line in output.splitlines():
        is_section_banner = (
            line.startswith("=") and line.endswith("=") and " tests coverage " in line
        )
        is_platform_banner = (
            line.startswith("_")
            and line.endswith("_")
            and " coverage: platform " in line
        )
        if not is_section_banner and not is_platform_banner:
            lines.append(line)
    return "\\n".join(lines).strip() + "\\n"

@click.command(name="unit-test")
def _embedded_unit_test_command() -> None:
    with tempfile.TemporaryDirectory(prefix="python-cli-coverage-") as directory:
        coverage_config = Path(directory) / ".coveragerc"
        coverage_config.write_text(
            os.linesep.join(
                (
                    "[run]",
                    "patch = subprocess",
                    "include =",
                    f"    {{Path(__file__).resolve().as_posix()}}",
                    "",
                )
            ),
            encoding="utf-8",
        )
        previous_coverage_file = os.environ.get("COVERAGE_FILE")
        os.environ["COVERAGE_FILE"] = str(Path(directory) / ".coverage")
        pytest_output = io.StringIO()
        try:
            with contextlib.redirect_stdout(pytest_output):
                result = pytest.main(
                    [
                        "--cov",
                        "--cov-branch",
                        "--cov-config",
                        str(coverage_config),
                        "--cov-report=term-missing",
                        "-p",
                        "no:cacheprovider",
                        __file__,
                        "-q",
                    ]
                )
        finally:
            if previous_coverage_file is None:
                os.environ.pop("COVERAGE_FILE", None)
            else:
                os.environ["COVERAGE_FILE"] = previous_coverage_file
    click.echo(compact_pytest_output(pytest_output.getvalue()), nl=False)
    raise SystemExit(result)

cli.add_command(_embedded_unit_test_command)
""".replace("# //__PEP_OPEN__", "# /// script")


def test_load_alias_policy_contains_expected_aliases() -> None:
    policy = load_alias_policy()

    assert policy["datetime"] == frozenset({"dt"})
    assert policy["structlog"] == frozenset({"sl"})
    assert policy["structlog.stdlib"] == frozenset({"log"})


@pytest.mark.parametrize(
    ("document", "expected"),
    [
        ("not valid = [toml", "cannot load import policy"),
        ("[other]\nvalue = 1\n", "must contain an aliases table"),
        ("[aliases]\ndatetime = 'dt'\n", "aliases must be string lists"),
    ],
)
def test_load_alias_policy_rejects_invalid_documents(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    document: str,
    expected: str,
) -> None:
    policy_path = tmp_path / "import-policy.toml"
    policy_path.write_text(document, encoding="utf-8")
    monkeypatch.setattr(
        sys.modules[__name__],
        "IMPORT_POLICY_PATH",
        policy_path,
    )

    with pytest.raises(ValidationError, match=expected):
        load_alias_policy()


def test_load_alias_policy_reports_unreadable_file(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        sys.modules[__name__],
        "IMPORT_POLICY_PATH",
        tmp_path / "missing.toml",
    )

    with pytest.raises(ValidationError, match="cannot load import policy"):
        load_alias_policy()


def test_extract_metadata_reads_exact_dependencies() -> None:
    metadata = extract_metadata(valid_script_source())

    assert metadata.requires_python == ">=3.14"
    assert metadata.dependency_names == REQUIRED_DEPENDENCIES


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        ("print('no metadata')\n", "missing a valid PEP 723"),
        (
            "# /// script\n# requires-python = '>=3.14'\n# dependencies = 'click'\n# ///\n",
            "invalid PEP 723 metadata",
        ),
        (
            "# /// script\n# requires-python = [\n# ///\n",
            "invalid PEP 723 metadata",
        ),
    ],
)
def test_extract_metadata_rejects_invalid_documents(
    source: str,
    expected: str,
) -> None:
    with pytest.raises(ValidationError, match=expected):
        extract_metadata(source)


def test_ast_helpers_cover_supported_and_unknown_shapes() -> None:
    assert decorator_name(ast.Name(id="command")) == "command"
    assert (
        decorator_name(ast.Attribute(value=ast.Name(id="click"), attr="group"))
        == "group"
    )
    assert decorator_name(ast.Constant(value="unknown")) is None
    assert decorator_keywords(ast.Name(id="command")) == {}

    call = ast.Call(
        func=ast.Name(id="command"),
        args=[],
        keywords=[
            ast.keyword(arg="hidden", value=ast.Constant(value=True)),
            ast.keyword(arg="name", value=ast.Name(id="dynamic")),
            ast.keyword(arg=None, value=ast.Name(id="options")),
        ],
    )
    assert decorator_keywords(call) == {"hidden": True}
    assert qualified_name(ast.Name(id="logger")) == "logger"
    assert (
        qualified_name(ast.Attribute(value=ast.Name(id="sl"), attr="configure"))
        == "sl.configure"
    )
    assert qualified_name(ast.Constant(value=None)) is None


@pytest.mark.parametrize(
    "body",
    [
        "pytest.main(arguments)",
        "pytest.main([])",
        "pytest.main([__file__])",
        "other.main([__file__])",
    ],
)
def test_invokes_embedded_pytest_rejects_incomplete_calls(body: str) -> None:
    tree = ast.parse(f"def unit_test():\n    {body}\n")
    function = tree.body[0]
    assert isinstance(function, ast.FunctionDef)

    assert not invokes_embedded_pytest(function)


def test_structural_errors_accept_valid_script(tmp_path: Path) -> None:
    target = tmp_path / "valid.py"
    target.write_text(valid_script_source(), encoding="utf-8")
    target.chmod(0o755)

    errors, metadata = structural_errors(target)

    assert errors == []
    assert metadata is not None


def test_structural_errors_requires_executable_bit(tmp_path: Path) -> None:
    target = tmp_path / "valid.py"
    target.write_text(valid_script_source(), encoding="utf-8")
    target.chmod(0o644)

    errors, metadata = structural_errors(target)

    assert metadata is not None
    assert "target must be executable; run chmod +x TARGET" in errors


def test_structural_errors_reports_combined_file_and_metadata_problems(
    tmp_path: Path,
) -> None:
    target = tmp_path / "invalid.txt"
    source = (
        valid_script_source()
        .replace(SHEBANG, "#!/usr/bin/python3")
        .replace('requires-python = ">=3.14"', 'requires-python = ">=3.13"')
        .replace('"click==8.4.2"', '"click"')
    )
    target.write_text(f"{source}\nthis is invalid syntax", encoding="utf-8")
    Path(f"{target}.lock").write_text("lock", encoding="utf-8")

    errors, metadata = structural_errors(target)

    assert metadata is not None
    assert "target must have a .py suffix" in errors
    assert any("first line" in error for error in errors)
    assert 'requires-python must be exactly ">=3.14"' in errors
    assert any("not exactly pinned: click" in error for error in errors)
    assert any("missing required dependencies: click" in error for error in errors)
    assert any("script lockfile must not exist" in error for error in errors)
    assert any("invalid Python syntax" in error for error in errors)


def test_structural_errors_rejects_missing_target(tmp_path: Path) -> None:
    target = tmp_path / "missing.py"

    assert structural_errors(target) == ([f"target is not a file: {target}"], None)


def test_structural_errors_reports_unreadable_target(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    target = tmp_path / "unreadable.py"
    target.write_text("placeholder", encoding="utf-8")

    def deny_read(_path: Path, *, encoding: str) -> str:
        del encoding
        raise PermissionError("permission denied")

    monkeypatch.setattr(Path, "read_text", deny_read)

    errors, metadata = structural_errors(target)

    assert metadata is None
    assert errors == ["cannot read target: permission denied"]


def test_structural_errors_reports_metadata_and_policy_failures(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    target = tmp_path / "invalid.py"
    target.write_text("print('missing metadata')\n", encoding="utf-8")

    errors, metadata = structural_errors(target)

    assert metadata is None
    assert any("missing a valid PEP 723" in error for error in errors)

    target.write_text(valid_script_source(), encoding="utf-8")
    monkeypatch.setattr(
        sys.modules[__name__],
        "IMPORT_POLICY_PATH",
        tmp_path / "missing-policy.toml",
    )

    errors, metadata = structural_errors(target)

    assert metadata is not None
    assert any("cannot load import policy" in error for error in errors)


def test_structural_errors_reject_wrong_import_alias(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(valid_script_source("import datetime"), encoding="utf-8")

    errors, _metadata = structural_errors(target)

    assert any("import datetime as dt" in error for error in errors)


def test_structural_errors_reject_from_import_workaround(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source("from importlib import metadata as md"),
        encoding="utf-8",
    )
    errors, _metadata = structural_errors(target)

    assert any("import importlib.metadata as md" in error for error in errors)


def test_inspect_imports_handles_all_policy_shapes() -> None:
    tree = ast.parse(
        """
import datetime as dt
import structlog as wrong
import structlog.dev as dev
import structlog.stdlib
from datetime import date
from structlog import configure
from structlog.dev import ConsoleRenderer
from importlib import metadata as md
from . import local
"""
    )

    errors = inspect_imports(tree, load_alias_policy())

    assert any("import structlog as sl" in error for error in errors)
    assert any("import structlog.stdlib as log" in error for error in errors)
    assert any("registered structlog module aliases" in error for error in errors)
    assert any("do not import from datetime" in error for error in errors)
    assert any("do not import from structlog" in error for error in errors)
    assert any("do not import structlog objects directly" in error for error in errors)
    assert any("import importlib.metadata as md" in error for error in errors)


def test_inspect_structlog_logger_handles_nonmatching_calls() -> None:
    tree = ast.parse(
        """
other: object = factory()
logger: log.BoundLogger = log.get_logger(__name__)
other_logger = log.get_logger(__name__)
logger = log.get_logger()
lg.get_logger()
unrelated()
sl.configure(cache_logger_on_first_use=False)
sl.configure(wrapper_class=sl.BoundLogger)
sl.configure(wrapper_class=sl.make_filtering_bound_logger("info"))
"""
    )

    errors = inspect_structlog_logger(tree)

    assert sum("construct the module logger exactly" in error for error in errors) == 3
    assert any(
        "line 6: use logger = log.get_logger(__name__)" in error for error in errors
    )
    assert "missing logger = log.get_logger(__name__)" in errors
    assert any("wrapper_class=sl.make_filtering" in error for error in errors)


def test_structural_errors_reject_legacy_hidden_test_command(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source()
        .replace('name="unit-test"', 'name="test", hidden=True')
        .replace("_embedded_unit_test_command", "_embedded_test_command"),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any('command named "test" is ambiguous' in error for error in errors)
    assert 'missing a visible Click command named "unit-test"' in errors


def test_structural_errors_reject_hidden_unit_test_command(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            'name="unit-test"',
            'name="unit-test", hidden=True',
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert 'Click command "unit-test" must be visible' in errors


def test_structural_errors_rejects_missing_check_command(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            """@cli.command(name="check")
def check_command() -> None:
    click.echo("ok")

""",
            "",
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert 'missing a visible Click command named "check"' in errors


def test_structural_errors_rejects_hidden_check_command(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            'name="check"',
            'name="check", hidden=True',
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert 'Click command "check" must be visible' in errors


def test_structural_errors_require_coverage_arguments(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace('"--cov-branch",', '"--no-cov",'),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("must run pytest for this file with --cov" in error for error in errors)


def test_structural_errors_require_temporary_coverage_data(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            "tempfile.TemporaryDirectory",
            "tempfile.NamedTemporaryFile",
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("isolate COVERAGE_FILE" in error for error in errors)


def test_structural_errors_require_script_only_coverage_filter(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace('"include ="', '"omit ="'),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("temporary [run] include" in error for error in errors)


def test_structural_errors_require_subprocess_coverage_patch(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            '"patch = subprocess",',
            '"parallel = true",',
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("isolate COVERAGE_FILE" in error for error in errors)


def test_structural_errors_require_coverage_file_override(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            'os.environ["COVERAGE_FILE"] =',
            "coverage_file =",
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("isolate COVERAGE_FILE" in error for error in errors)


def test_structural_errors_require_compact_coverage_output(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            "contextlib.redirect_stdout",
            "contextlib.nullcontext",
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("suppress pytest-cov" in error for error in errors)


def test_structural_errors_require_coverage_banner_markers(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            '" coverage: platform "',
            '" platform "',
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("suppress pytest-cov" in error for error in errors)


def test_structural_errors_require_visible_task_beside_unit_test(
    tmp_path: Path,
) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            """@cli.command(name="run")
def run_command() -> None:
    pass

""",
            "",
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert "missing a visible Click task command" in errors


def test_structural_errors_require_click_group(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace("@click.group()", "@click.command()"),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert "missing a Click group" in errors


def test_structural_errors_ignores_hidden_tasks(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            '@cli.command(name="run")',
            '@cli.command(name="run", hidden=True)',
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert "missing a visible Click task command" in errors


def test_structural_errors_accepts_default_and_async_command_names(
    tmp_path: Path,
) -> None:
    target = tmp_path / "valid.py"
    target.write_text(
        valid_script_source()
        .replace('@cli.command(name="run")', "@cli.command()")
        .replace("def run_command()", "async def run_command()"),
        encoding="utf-8",
    )
    target.chmod(0o755)

    errors, _metadata = structural_errors(target)

    assert errors == []


def test_structural_errors_requires_subprocess_timeout(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source("import subprocess as sp")
        + '\ndef call_process() -> None:\n    sp.run(["true"], check=False)\n',
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("subprocess.run must set a timeout" in error for error in errors)
    assert (
        inspect_subprocess_timeouts(
            ast.parse('sp.run(["true"], check=False, timeout=10)')
        )
        == []
    )


def test_structural_errors_reject_wrong_structlog_alias(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            "import structlog as sl", "import structlog as lg"
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("import structlog as sl" in error for error in errors)


def test_structural_errors_require_structlog_logger(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            "logger = log.get_logger(__name__)\n",
            "",
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert "missing logger = log.get_logger(__name__)" in errors


def test_structural_errors_reject_nonstandard_structlog_logger(
    tmp_path: Path,
) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            "logger = log.get_logger(__name__)",
            "logger: log.BoundLogger = log.get_logger()",
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("construct the module logger exactly" in error for error in errors)
    assert "missing logger = log.get_logger(__name__)" in errors


def test_structural_errors_require_matching_structlog_wrapper(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text(
        valid_script_source().replace(
            'wrapper_class=sl.make_filtering_bound_logger("debug")',
            "wrapper_class=sl.BoundLogger",
        ),
        encoding="utf-8",
    )

    errors, _metadata = structural_errors(target)

    assert any("wrapper_class=sl.make_filtering" in error for error in errors)


def test_quality_commands_include_every_gate(tmp_path: Path) -> None:
    target = tmp_path / "tool.py"
    metadata = extract_metadata(valid_script_source())

    commands = quality_commands(target, metadata)

    assert len(commands) == 7
    assert commands[2][2] == "ty"
    assert commands[3][2:5] == ["pyrefly", "--with", "click==8.4.2"]
    assert commands[3][-8:] == [
        "check",
        "--preset",
        "basic",
        "--python-version",
        "3.14",
        "--progress-bar",
        "no",
        str(target),
    ]
    assert commands[-3:] == [
        [str(target.resolve()), "--help"],
        [str(target.resolve()), "check"],
        [str(target.resolve()), "unit-test"],
    ]


@pytest.mark.parametrize(("returncode", "expected"), [(0, True), (2, False)])
def test_run_check_reports_process_status(
    monkeypatch: pytest.MonkeyPatch,
    returncode: int,
    expected: bool,
) -> None:
    observed_environment: dict[str, str] = {}
    monkeypatch.setenv("VIRTUAL_ENV", "/temporary/environment")
    monkeypatch.setenv("PYTHONPATH", "/ambient/site-packages")

    def fake_run(
        command: Sequence[str],
        *,
        check: bool,
        env: dict[str, str],
        timeout: int,
    ) -> sp.CompletedProcess[str]:
        del check
        assert timeout == QUALITY_CHECK_TIMEOUT_SECONDS
        observed_environment.update(env)
        return sp.CompletedProcess(command, returncode)

    monkeypatch.setattr(sp, "run", fake_run)

    assert run_check(["quality-tool", "check"]) is expected
    assert "VIRTUAL_ENV" not in observed_environment
    assert "PYTHONPATH" not in observed_environment


def test_run_check_requires_exact_stdout(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_run(
        command: Sequence[str],
        *,
        check: bool,
        env: dict[str, str],
        stdout: int,
        text: bool,
        timeout: int,
    ) -> sp.CompletedProcess[str]:
        del check, env
        assert stdout == sp.PIPE
        assert text
        assert timeout == QUALITY_CHECK_TIMEOUT_SECONDS
        return sp.CompletedProcess(command, 0, stdout="ready\n")

    monkeypatch.setattr(sp, "run", fake_run)

    assert not run_check(
        ["quality-tool", "check"],
        expected_stdout="ok\n",
    )


def test_run_check_reports_missing_command(monkeypatch: pytest.MonkeyPatch) -> None:
    def missing_command(
        command: Sequence[str],
        *,
        check: bool,
        env: dict[str, str],
        timeout: int,
    ) -> sp.CompletedProcess[str]:
        del command, check, env, timeout
        raise FileNotFoundError(2, "not found", "missing-tool")

    monkeypatch.setattr(sp, "run", missing_command)

    assert not run_check(["missing-tool"])


def test_run_check_reports_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    def timed_out(
        command: Sequence[str],
        *,
        check: bool,
        env: dict[str, str],
        timeout: int,
    ) -> sp.CompletedProcess[str]:
        del check, env
        raise sp.TimeoutExpired(command, timeout)

    monkeypatch.setattr(sp, "run", timed_out)

    assert not run_check(["slow-tool"])


def test_validate_target_reports_unavailable_metadata(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def no_metadata(_target: Path) -> tuple[list[str], ScriptMetadata | None]:
        return [], None

    monkeypatch.setattr(sys.modules[__name__], "structural_errors", no_metadata)

    assert validate_target(tmp_path / "tool.py", structural_only=False) == [
        "metadata unavailable after validation"
    ]


def test_validate_target_runs_all_quality_checks(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    metadata = extract_metadata(valid_script_source())

    def valid_structure(_target: Path) -> tuple[list[str], ScriptMetadata | None]:
        return [], metadata

    def fake_commands(
        _target: Path,
        _metadata: ScriptMetadata,
    ) -> list[list[str]]:
        return [["passing"], ["failing", "check"]]

    def fake_run_check(
        command: Sequence[str],
        *,
        expected_stdout: str | None,
    ) -> bool:
        del expected_stdout
        return command[0] == "passing"

    module = sys.modules[__name__]
    monkeypatch.setattr(module, "structural_errors", valid_structure)
    monkeypatch.setattr(module, "quality_commands", fake_commands)
    monkeypatch.setattr(module, "run_check", fake_run_check)

    assert validate_target(tmp_path / "tool.py", structural_only=False) == [
        "quality check failed: failing check"
    ]


def test_cli_help_shows_unit_test_command() -> None:
    result = CliRunner().invoke(cli, ["--help"])

    assert result.exit_code == 0
    assert "check" in result.stdout
    assert "validate" in result.stdout
    assert "unit-test" in result.stdout


def test_validate_command_runs_structural_validation(tmp_path: Path) -> None:
    target = tmp_path / "valid.py"
    target.write_text(valid_script_source(), encoding="utf-8")
    target.chmod(0o755)

    result = CliRunner().invoke(cli, ["validate", str(target), "--structural-only"])

    assert result.exit_code == 0
    assert result.stdout == "Structural validation passed.\n"


def test_validate_command_reports_validation_failure(tmp_path: Path) -> None:
    target = tmp_path / "invalid.py"
    target.write_text("print('invalid')\n", encoding="utf-8")

    result = CliRunner().invoke(cli, ["validate", str(target), "--structural-only"])

    assert result.exit_code == 1
    assert "validation failed" in result.stderr


def test_validate_command_reports_full_validation_success(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def successful_validation(_target: Path, *, structural_only: bool) -> list[str]:
        assert not structural_only
        return []

    monkeypatch.setattr(
        sys.modules[__name__],
        "validate_target",
        successful_validation,
    )

    result = CliRunner().invoke(cli, ["validate", str(tmp_path / "tool.py")])

    assert result.exit_code == 0
    assert result.stdout == "All quality gates passed.\n"


def test_check_command_reports_readiness(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(shutil, "which", lambda _command: "/usr/bin/uvx")

    result = CliRunner().invoke(cli, ["check"])

    assert result.exit_code == 0
    assert result.stdout == "ok\n"


def test_check_command_reports_missing_uvx(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(shutil, "which", lambda _command: None)

    result = CliRunner().invoke(cli, ["check"])

    assert result.exit_code == 1
    assert "uvx is required" in result.stderr


@pytest.mark.parametrize(
    "line",
    [
        "= incomplete section banner",
        "= unrelated section =",
        "_ incomplete platform banner",
        "_ unrelated platform _",
    ],
)
def test_compact_pytest_output_preserves_similar_lines(line: str) -> None:
    assert compact_pytest_output(line) == f"{line}\n"


def test_compact_pytest_output_removes_coverage_banners() -> None:
    output = "\n".join(
        (
            ".... [100%]",
            "===== tests coverage =====",
            "_____ coverage: platform linux, python 3.14 _____",
            "TOTAL 10 0 100%",
        )
    )

    assert compact_pytest_output(output) == ".... [100%]\nTOTAL 10 0 100%\n"


@pytest.mark.parametrize("previous_coverage_file", [None, "existing-coverage"])
def test_unit_test_command_isolates_coverage_and_restores_environment(
    monkeypatch: pytest.MonkeyPatch,
    previous_coverage_file: str | None,
) -> None:
    observed_config = ""
    observed_coverage_file = ""

    if previous_coverage_file is None:
        monkeypatch.delenv("COVERAGE_FILE", raising=False)
    else:
        monkeypatch.setenv("COVERAGE_FILE", previous_coverage_file)

    def fake_pytest_main(arguments: list[str]) -> pytest.ExitCode:
        nonlocal observed_config, observed_coverage_file
        config_index = arguments.index("--cov-config") + 1
        observed_config = Path(arguments[config_index]).read_text(encoding="utf-8")
        observed_coverage_file = os.environ["COVERAGE_FILE"]
        print("===== tests coverage =====")
        print("_____ coverage: platform linux, python 3.14 _____")
        print("TOTAL 1 0 100%")
        return pytest.ExitCode.OK

    monkeypatch.setattr(pytest, "main", fake_pytest_main)

    result = CliRunner().invoke(_embedded_unit_test_command)

    assert result.exit_code == 0
    assert result.stdout == "TOTAL 1 0 100%\n"
    assert "patch = subprocess" in observed_config
    assert Path(observed_coverage_file).name == ".coverage"
    assert os.environ.get("COVERAGE_FILE") == previous_coverage_file


def test_script_entrypoint_shows_help() -> None:
    result = sp.run(
        [sys.executable, __file__, "--help"],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )

    assert result.returncode == 0
    assert "Validate one-file Python CLIs" in result.stdout


if __name__ == "__main__":
    cli()
