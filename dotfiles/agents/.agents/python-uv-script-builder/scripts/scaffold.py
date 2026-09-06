#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""Scaffold a one-file Python CLI and pin its runtime dependencies."""

import contextlib
import io
import os
import re
import shutil
import subprocess as sp
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

import click
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner

COMMAND_RE = re.compile(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*")
DEPENDENCY_PIN_TIMEOUT_SECONDS = 120
logger = log.get_logger(__name__)

BASE_TEMPLATE = '''\
#!/usr/bin/env -S uv run --script
# //__PEP_OPEN__
# requires-python = ">=3.14"
# dependencies = []
# ///

"""Provide a concise description of this command-line tool."""

import contextlib
import io
import os
import subprocess as sp
import sys
import tempfile
from pathlib import Path

import click
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner

logger = log.get_logger(__name__)


class InputError(Exception):
    """Report invalid domain input supplied to the command."""


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


def build_message(name: str) -> str:
    """Build the example result while enforcing its domain invariant."""
    cleaned_name = name.strip()
    if not cleaned_name:
        raise InputError("name must not be empty")
    return f"Hello, {cleaned_name}!"


@click.group()
def cli() -> None:
    """Run this tool's commands."""
    configure_logging()


@cli.command(name="__COMMAND_NAME__")
@click.option("--name", default="world", show_default=True, help="Name to greet.")
def task_command(name: str) -> None:
    """Run the example task."""
    try:
        message = build_message(name)
    except InputError as error:
        raise click.ClickException(str(error)) from error

    logger.info("task_completed", name=name.strip())
    click.echo(message)


@cli.command(name="check")
def check_command() -> None:
    """Verify that this tool's runtime setup is ready."""
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
    return "\\n".join(lines).strip() + "\\n"


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


def test_build_message() -> None:
    assert build_message(" Codex ") == "Hello, Codex!"


def test_build_message_rejects_empty_name() -> None:
    with pytest.raises(InputError, match="name must not be empty"):
        build_message("   ")


def test_cli_help_shows_unit_test_command() -> None:
    result = CliRunner().invoke(cli, ["--help"])

    assert result.exit_code == 0
    assert "__COMMAND_NAME__" in result.stdout
    assert "check" in result.stdout
    assert "unit-test" in result.stdout


def test_check_command_reports_readiness() -> None:
    result = CliRunner().invoke(cli, ["check"])

    assert result.exit_code == 0
    assert result.stdout == "ok\n"


def test_task_command_separates_output_and_logs() -> None:
    result = sp.run(
        [sys.executable, __file__, "__COMMAND_NAME__", "--name", "Codex"],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )

    assert result.returncode == 0
    assert result.stdout == "Hello, Codex!\\n"
    assert "task_completed" in result.stderr


if __name__ == "__main__":
    cli()
'''.replace("# //__PEP_OPEN__", "# /// script")

type DependencyPinner = Callable[[Path, bool], None]


class ScaffoldError(Exception):
    """Report a failure that prevents scaffolding a complete script."""


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


def validate_inputs(output: Path, command_name: str) -> None:
    if output.suffix != ".py":
        raise ScaffoldError("output must have a .py suffix")
    if output.exists():
        raise ScaffoldError(f"output already exists: {output}")
    if not COMMAND_RE.fullmatch(command_name):
        raise ScaffoldError(
            "command name must use lowercase hyphen-case, for example sync-repos"
        )
    if shutil.which("uv") is None:
        raise ScaffoldError("uv is required but was not found on PATH")


def pin_dependencies(output: Path, with_pydantic: bool) -> None:
    packages = ["click", "pytest", "pytest-cov", "structlog"]
    if with_pydantic:
        packages.append("pydantic")

    command = [
        "uv",
        "add",
        "--script",
        str(output),
        "--bounds",
        "exact",
        *packages,
    ]
    try:
        process = sp.run(
            command,
            check=False,
            text=True,
            stdout=sp.PIPE,
            stderr=sp.STDOUT,
            timeout=DEPENDENCY_PIN_TIMEOUT_SECONDS,
        )
    except sp.TimeoutExpired as error:
        raise ScaffoldError(
            "dependency resolution timed out after "
            f"{DEPENDENCY_PIN_TIMEOUT_SECONDS} seconds"
        ) from error
    if process.returncode != 0:
        details = process.stdout.strip() or "uv returned no diagnostic output"
        raise ScaffoldError(f"could not pin dependencies: {details}")


def scaffold(
    output: Path,
    command_name: str,
    *,
    with_pydantic: bool,
    dry_run: bool = False,
    dependency_pinner: DependencyPinner = pin_dependencies,
) -> None:
    validate_inputs(output, command_name)
    source = BASE_TEMPLATE.replace("__COMMAND_NAME__", command_name)

    if dry_run:
        with tempfile.TemporaryDirectory(prefix="python-cli-scaffold-") as directory:
            staged_output = Path(directory) / output.name
            staged_output.write_text(source, encoding="utf-8")
            dependency_pinner(staged_output, with_pydantic)
        return

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(source, encoding="utf-8")

    try:
        dependency_pinner(output, with_pydantic)
    except Exception:
        output.unlink(missing_ok=True)
        Path(f"{output}.lock").unlink(missing_ok=True)
        raise

    output.chmod(0o755)


def output_message(output: Path) -> str:
    return f"Created executable {output} with exact runtime dependency pins."


@click.group()
def cli() -> None:
    """Create Python scripts that follow the Python uv Script Builder standard."""
    configure_logging()


@cli.command(name="create")
@click.argument("output", type=click.Path(path_type=Path, dir_okay=False))
@click.option(
    "--command-name",
    required=True,
    help="Visible Click command name in lowercase hyphen-case.",
)
@click.option(
    "--with-pydantic",
    is_flag=True,
    help="Add an exact Pydantic pin for structured input models.",
)
@click.option(
    "--dry-run",
    is_flag=True,
    help="Validate and resolve in a temporary directory without creating OUTPUT.",
)
def create_command(
    output: Path,
    command_name: str,
    *,
    with_pydantic: bool,
    dry_run: bool,
) -> None:
    """Create a new script at OUTPUT and pin its base dependencies."""
    try:
        scaffold(
            output,
            command_name,
            with_pydantic=with_pydantic,
            dry_run=dry_run,
        )
    except ScaffoldError as error:
        raise click.ClickException(str(error)) from error

    if dry_run:
        logger.info(
            "script_creation_planned",
            output=str(output),
            command_name=command_name,
            with_pydantic=with_pydantic,
        )
        click.echo(f"Dry run succeeded; would create executable {output}.")
        return

    logger.info(
        "script_created",
        output=str(output),
        command_name=command_name,
        with_pydantic=with_pydantic,
    )
    click.echo(output_message(output))


@cli.command(name="check")
def check_command() -> None:
    """Verify that the scaffolder's runtime setup is ready."""
    if shutil.which("uv") is None:
        raise click.ClickException("uv is required but was not found on PATH")
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


def test_compact_pytest_output_removes_only_coverage_banners() -> None:
    output = "\n".join(
        (
            ".... [100%]",
            "===== tests coverage =====",
            "_____ coverage: platform linux, python 3.14 _____",
            "Name  Stmts  Cover",
            "tool.py  10  80%",
            "1 failed in 0.01s",
        )
    )

    assert compact_pytest_output(output) == "\n".join(
        (
            ".... [100%]",
            "Name  Stmts  Cover",
            "tool.py  10  80%",
            "1 failed in 0.01s",
            "",
        )
    )


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


def test_validate_inputs_rejects_non_python_output(tmp_path: Path) -> None:
    with pytest.raises(ScaffoldError, match=".py suffix"):
        validate_inputs(tmp_path / "tool.txt", "run")


def test_validate_inputs_rejects_invalid_command_name(tmp_path: Path) -> None:
    with pytest.raises(ScaffoldError, match="lowercase hyphen-case"):
        validate_inputs(tmp_path / "tool.py", "Not Valid")


def test_validate_inputs_rejects_existing_output(tmp_path: Path) -> None:
    output = tmp_path / "tool.py"
    output.write_text("", encoding="utf-8")

    with pytest.raises(ScaffoldError, match="output already exists"):
        validate_inputs(output, "run")


def test_validate_inputs_requires_uv(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(shutil, "which", lambda _command: None)

    with pytest.raises(ScaffoldError, match="uv is required"):
        validate_inputs(tmp_path / "tool.py", "run")


def test_pin_dependencies_builds_exact_uv_command(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands: list[list[str]] = []

    def fake_run(command: list[str], **_kwargs: object) -> sp.CompletedProcess[str]:
        commands.append(command)
        return sp.CompletedProcess(command, 0, stdout="")

    monkeypatch.setattr(sp, "run", fake_run)
    output = tmp_path / "tool.py"

    pin_dependencies(output, True)

    assert commands == [
        [
            "uv",
            "add",
            "--script",
            str(output),
            "--bounds",
            "exact",
            "click",
            "pytest",
            "pytest-cov",
            "structlog",
            "pydantic",
        ]
    ]


@pytest.mark.parametrize(
    ("diagnostic", "expected"),
    [
        (" resolution failed \n", "resolution failed"),
        ("", "uv returned no diagnostic output"),
    ],
)
def test_pin_dependencies_reports_uv_failure(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    diagnostic: str,
    expected: str,
) -> None:
    def fake_run(command: list[str], **_kwargs: object) -> sp.CompletedProcess[str]:
        return sp.CompletedProcess(command, 1, stdout=diagnostic)

    monkeypatch.setattr(sp, "run", fake_run)

    with pytest.raises(ScaffoldError, match=expected):
        pin_dependencies(tmp_path / "tool.py", False)


def test_pin_dependencies_reports_timeout(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def timed_out(
        command: list[str],
        **_kwargs: object,
    ) -> sp.CompletedProcess[str]:
        raise sp.TimeoutExpired(command, DEPENDENCY_PIN_TIMEOUT_SECONDS)

    monkeypatch.setattr(sp, "run", timed_out)

    with pytest.raises(ScaffoldError, match="timed out after 120 seconds"):
        pin_dependencies(tmp_path / "tool.py", False)


def test_scaffold_writes_executable_template(tmp_path: Path) -> None:
    output = tmp_path / "tool.py"
    calls: list[tuple[Path, bool]] = []

    def fake_pinner(path: Path, with_pydantic: bool) -> None:
        calls.append((path, with_pydantic))

    scaffold(
        output,
        "sync-repos",
        with_pydantic=True,
        dependency_pinner=fake_pinner,
    )

    source = output.read_text(encoding="utf-8")
    assert source.startswith("#!/usr/bin/env -S uv run --script\n")
    assert '@cli.command(name="sync-repos")' in source
    assert '@cli.command(name="check")' in source
    assert '@click.command(name="unit-test")' in source
    assert calls == [(output, True)]
    assert output.stat().st_mode & 0o111


def test_scaffold_removes_partial_output_after_pin_failure(tmp_path: Path) -> None:
    output = tmp_path / "tool.py"
    lockfile = Path(f"{output}.lock")

    def failing_pinner(path: Path, _with_pydantic: bool) -> None:
        Path(f"{path}.lock").write_text("partial", encoding="utf-8")
        raise ScaffoldError("resolution failed")

    with pytest.raises(ScaffoldError, match="resolution failed"):
        scaffold(
            output,
            "run",
            with_pydantic=False,
            dependency_pinner=failing_pinner,
        )

    assert not output.exists()
    assert not lockfile.exists()


def test_scaffold_dry_run_uses_temporary_output(tmp_path: Path) -> None:
    output = tmp_path / "nested" / "tool.py"
    staged_paths: list[Path] = []

    def fake_pinner(path: Path, _with_pydantic: bool) -> None:
        staged_paths.append(path)
        assert path.is_file()
        assert path.name == output.name

    scaffold(
        output,
        "run",
        with_pydantic=False,
        dry_run=True,
        dependency_pinner=fake_pinner,
    )

    assert len(staged_paths) == 1
    assert not staged_paths[0].exists()
    assert not output.exists()
    assert not output.parent.exists()


def test_output_message_describes_exact_pins(tmp_path: Path) -> None:
    output = tmp_path / "tool.py"

    assert output_message(output) == (
        f"Created executable {output} with exact runtime dependency pins."
    )


def test_cli_help_shows_unit_test_command() -> None:
    result = CliRunner().invoke(cli, ["--help"])

    assert result.exit_code == 0
    assert "create" in result.stdout
    assert "check" in result.stdout
    assert "unit-test" in result.stdout


def test_check_command_reports_readiness(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(shutil, "which", lambda _command: "/usr/bin/uv")

    result = CliRunner().invoke(cli, ["check"])

    assert result.exit_code == 0
    assert result.stdout == "ok\n"


def test_create_command_reports_domain_error(tmp_path: Path) -> None:
    result = CliRunner().invoke(
        cli,
        ["create", str(tmp_path / "tool.txt"), "--command-name", "run"],
    )

    assert result.exit_code == 1
    assert "output must have a .py suffix" in result.stderr


def test_create_command_reports_success(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[tuple[Path, str, bool, bool]] = []

    def fake_scaffold(
        output: Path,
        command_name: str,
        *,
        with_pydantic: bool,
        dry_run: bool,
    ) -> None:
        calls.append((output, command_name, with_pydantic, dry_run))

    monkeypatch.setattr(sys.modules[__name__], "scaffold", fake_scaffold)
    output = tmp_path / "tool.py"

    result = CliRunner().invoke(
        cli,
        [
            "create",
            str(output),
            "--command-name",
            "sync-repos",
            "--with-pydantic",
        ],
    )

    assert result.exit_code == 0
    assert result.stdout == (
        f"Created executable {output} with exact runtime dependency pins.\n"
    )
    assert calls == [(output, "sync-repos", True, False)]


def test_create_command_dry_run_does_not_create_output(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[tuple[Path, str, bool, bool]] = []

    def fake_scaffold(
        output: Path,
        command_name: str,
        *,
        with_pydantic: bool,
        dry_run: bool,
    ) -> None:
        calls.append((output, command_name, with_pydantic, dry_run))

    monkeypatch.setattr(sys.modules[__name__], "scaffold", fake_scaffold)
    output = tmp_path / "tool.py"

    result = CliRunner().invoke(
        cli,
        [
            "create",
            str(output),
            "--command-name",
            "sync-repos",
            "--dry-run",
        ],
    )

    assert result.exit_code == 0
    assert result.stdout == f"Dry run succeeded; would create executable {output}.\n"
    assert calls == [(output, "sync-repos", False, True)]


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
    assert "Create Python scripts" in result.stdout


def test_logging_uses_stderr(capsys: pytest.CaptureFixture[str]) -> None:
    configure_logging()
    logger.info("test_event", value=1)

    captured = capsys.readouterr()
    assert captured.out == ""
    assert "test_event" in captured.err


if __name__ == "__main__":
    cli()
