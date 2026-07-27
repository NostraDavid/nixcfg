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

"""Generate a root allowlist-style .gitignore from direct directory entries."""

from __future__ import annotations

import contextlib
import io
import os
import subprocess as sp
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import click
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner

logger = log.get_logger(__name__)


class GenerationError(Exception):
    """Report an expected failure while planning or writing the ignore file."""


@dataclass(frozen=True)
class Entry:
    """Describe one direct child without coupling rendering to the filesystem."""

    name: str
    is_directory: bool


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


def escape_gitignore_literal(name: str) -> str:
    """Escape metacharacters in one path component for a gitignore pattern."""
    escaped = name.replace("\\", "\\\\")
    for character in ("[", "]", "*", "?"):
        escaped = escaped.replace(character, f"\\{character}")
    return escaped


def render_gitignore(entries: tuple[Entry, ...]) -> str:
    """Render deterministic patterns for files and directories."""
    ordered = sorted(entries, key=lambda entry: entry.name)
    directories = tuple(entry for entry in ordered if entry.is_directory)
    files = tuple(entry for entry in ordered if not entry.is_directory)
    lines = [
        "# ignore all direct items, nonrecursively",
        "/*",
        "",
        "# unignore folders",
        *(f"!/{escape_gitignore_literal(entry.name)}/" for entry in directories),
        "",
        "# unignore files",
        *(f"!/{escape_gitignore_literal(entry.name)}" for entry in files),
        "",
        "# reignore subfolders/files *anywhere* in the project",
        "__pycache__/",
        "*.egg-info/",
    ]
    return "\n".join(lines) + "\n"


def resolve_paths(directory: Path, output: Path) -> tuple[Path, Path]:
    """Resolve the source directory and require a direct-child output file."""
    resolved_directory = directory.expanduser().resolve()
    if not resolved_directory.is_dir():
        raise GenerationError(f"directory does not exist: {resolved_directory}")

    resolved_output = (
        output.expanduser().resolve()
        if output.is_absolute()
        else (resolved_directory / output).resolve()
    )
    if resolved_output.parent != resolved_directory:
        raise GenerationError("output must be a direct child of the directory")
    if resolved_output.exists() and resolved_output.is_dir():
        raise GenerationError(f"output is a directory: {resolved_output}")
    return resolved_directory, resolved_output


def discover_entries(directory: Path, output: Path) -> tuple[Entry, ...]:
    """Read all direct entries, including dotfiles, and include a new output."""
    try:
        discovered = {
            entry.name: Entry(name=entry.name, is_directory=entry.is_dir())
            for entry in directory.iterdir()
        }
    except OSError as error:
        raise GenerationError(f"cannot read directory {directory}: {error}") from error

    discovered.setdefault(output.name, Entry(name=output.name, is_directory=False))
    return tuple(discovered.values())


def atomic_write(output: Path, content: str) -> None:
    """Replace the output atomically while retaining its existing permissions."""
    mode = output.stat().st_mode & 0o777 if output.exists() else 0o644
    temporary_path: Path | None = None
    try:
        descriptor, raw_path = tempfile.mkstemp(
            dir=output.parent,
            prefix=f".{output.name}.",
        )
        temporary_path = Path(raw_path)
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        temporary_path.chmod(mode)
        temporary_path.replace(output)
    except OSError as error:
        raise GenerationError(f"cannot write {output}: {error}") from error
    finally:
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink()


@click.group()
def cli() -> None:
    """Build and validate an allowlist-style .gitignore."""
    configure_logging()


@cli.command(name="generate")
@click.option(
    "--directory",
    type=click.Path(path_type=Path, file_okay=False),
    default=Path("."),
    show_default=True,
    help="Directory whose direct entries are inventoried.",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path, dir_okay=False),
    default=Path(".gitignore"),
    show_default=True,
    help="Direct-child ignore file to write.",
)
@click.option(
    "--dry-run",
    is_flag=True,
    help="Print the planned content without writing or prompting.",
)
@click.option(
    "--yes",
    is_flag=True,
    help="Overwrite an existing output without confirmation.",
)
def generate_command(
    directory: Path,
    output: Path,
    *,
    dry_run: bool,
    yes: bool,
) -> None:
    """Generate the ignore file from direct files and folders."""
    try:
        resolved_directory, resolved_output = resolve_paths(directory, output)
        content = render_gitignore(
            discover_entries(resolved_directory, resolved_output)
        )
        if dry_run:
            click.echo(content, nl=False)
            return
        if resolved_output.exists() and not yes:
            click.confirm(f"Overwrite {resolved_output}?", abort=True)
        atomic_write(resolved_output, content)
    except GenerationError as error:
        raise click.ClickException(str(error)) from error

    logger.info("gitignore_generated", output=str(resolved_output))
    click.echo(resolved_output)


@cli.command(name="check")
@click.option(
    "--directory",
    type=click.Path(path_type=Path, file_okay=False),
    default=Path("."),
    show_default=True,
    help="Directory to verify.",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path, dir_okay=False),
    default=Path(".gitignore"),
    show_default=True,
    help="Direct-child output path to verify.",
)
def check_command(directory: Path, output: Path) -> None:
    """Verify read and write readiness without changing the filesystem."""
    try:
        resolved_directory, resolved_output = resolve_paths(directory, output)
        discover_entries(resolved_directory, resolved_output)
        if not os.access(resolved_directory, os.R_OK | os.X_OK):
            raise GenerationError(f"directory is not readable: {resolved_directory}")
        if not os.access(resolved_directory, os.W_OK):
            raise GenerationError(f"directory is not writable: {resolved_directory}")
        if resolved_output.exists() and not os.access(resolved_output, os.W_OK):
            raise GenerationError(f"output is not writable: {resolved_output}")
    except GenerationError as error:
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
    with tempfile.TemporaryDirectory(
        prefix="generate-gitignore-coverage-"
    ) as directory:
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


def test_render_includes_dotfiles_and_directory_suffixes() -> None:
    content = render_gitignore(
        (
            Entry("normal.txt", False),
            Entry(".env", False),
            Entry("src", True),
            Entry(".config", True),
        )
    )

    assert "!/.env\n" in content
    assert "!/.config/\n" in content
    assert "!/src/\n" in content
    assert "!/normal.txt\n" in content


def test_render_escapes_pattern_metacharacters() -> None:
    content = render_gitignore((Entry("literal[1]*?.txt", False),))

    assert "!/literal\\[1\\]\\*\\?.txt\n" in content


def test_dry_run_includes_output_without_mutating(tmp_path: Path) -> None:
    (tmp_path / ".env").touch()
    (tmp_path / "src").mkdir()
    runner = CliRunner()

    result = runner.invoke(
        cli,
        ["generate", "--directory", str(tmp_path), "--dry-run"],
    )

    assert result.exit_code == 0
    assert "!/.env\n" in result.stdout
    assert "!/.gitignore\n" in result.stdout
    assert "!/src/\n" in result.stdout
    assert not (tmp_path / ".gitignore").exists()


def test_generate_requires_confirmation_and_preserves_mode(tmp_path: Path) -> None:
    output = tmp_path / ".gitignore"
    output.write_text("old\n", encoding="utf-8")
    output.chmod(0o640)
    runner = CliRunner()

    aborted = runner.invoke(
        cli,
        ["generate", "--directory", str(tmp_path)],
        input="n\n",
    )
    content_after_abort = output.read_text(encoding="utf-8")
    generated = runner.invoke(
        cli,
        ["generate", "--directory", str(tmp_path), "--yes"],
    )

    assert aborted.exit_code == 1
    assert content_after_abort == "old\n"
    assert output.read_text(encoding="utf-8") != "old\n"
    assert generated.exit_code == 0
    assert output.stat().st_mode & 0o777 == 0o640


def test_check_reports_exact_readiness_result(tmp_path: Path) -> None:
    result = CliRunner().invoke(cli, ["check", "--directory", str(tmp_path)])

    assert result.exit_code == 0
    assert result.stdout == "ok\n"


def test_rejects_nested_output(tmp_path: Path) -> None:
    result = CliRunner().invoke(
        cli,
        [
            "generate",
            "--directory",
            str(tmp_path),
            "--output",
            "nested/.gitignore",
            "--dry-run",
        ],
    )

    assert result.exit_code == 1
    assert "output must be a direct child" in result.stderr


def test_cli_help_lists_all_commands() -> None:
    result = CliRunner().invoke(cli, ["--help"])

    assert result.exit_code == 0
    assert "generate" in result.stdout
    assert "check" in result.stdout
    assert "unit-test" in result.stdout


def test_generate_subprocess_separates_output_and_logs(tmp_path: Path) -> None:
    result = sp.run(
        [
            sys.executable,
            __file__,
            "generate",
            "--directory",
            str(tmp_path),
            "--yes",
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )

    assert result.returncode == 0
    assert result.stdout.strip() == str(tmp_path / ".gitignore")
    assert "gitignore_generated" in result.stderr


if __name__ == "__main__":
    cli()
