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

"""Find Git repositories with uncommitted or unpushed changes."""

import contextlib
import io
import os
import shutil
import subprocess as sp
import sys
import tempfile
from collections.abc import Callable
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

import click
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner

logger = log.get_logger(__name__)
GitRunner = Callable[[Path, list[str]], sp.CompletedProcess[str]]


class IssueKind(StrEnum):
    UNCOMMITTED = "uncommitted"
    UNPUSHED = "unpushed"


@dataclass(frozen=True, slots=True)
class RepoIssue:
    path: Path
    kind: IssueKind


class ScanError(Exception):
    """Report an expected repository scan failure."""


def configure_logging() -> None:
    sl.configure(
        processors=[
            sl.processors.TimeStamper(fmt="iso"),
            sl.processors.add_log_level,
            sl.dev.ConsoleRenderer(colors=sys.stderr.isatty()),
        ],
        wrapper_class=sl.make_filtering_bound_logger("debug"),
        logger_factory=sl.PrintLoggerFactory(file=sys.stderr),
        cache_logger_on_first_use=False,
    )


def run_git(repo_path: Path, arguments: list[str]) -> sp.CompletedProcess[str]:
    return sp.run(  # noqa: S603 - fixed executable and argument vector
        ["git", *arguments],  # noqa: S607 - Git intentionally resolved from PATH
        cwd=repo_path,
        check=False,
        text=True,
        capture_output=True,
        timeout=30,
    )


def repo_paths(search_dir: Path) -> list[Path]:
    paths: list[Path] = []
    for root, directories, files in os.walk(search_dir):
        if ".git" in directories:
            paths.append(Path(root))
            directories.remove(".git")
        elif ".git" in files:
            paths.append(Path(root))
    return sorted(paths)


def inspect_repo(repo_path: Path, runner: GitRunner = run_git) -> RepoIssue | None:
    status = runner(repo_path, ["status", "--porcelain", "--ignore-submodules"])
    if status.returncode != 0:
        message = status.stderr.strip() or "git status failed"
        raise ScanError(f"{repo_path}: {message}")
    if status.stdout:
        return RepoIssue(repo_path, IssueKind.UNCOMMITTED)
    unpushed = runner(repo_path, ["log", "@{u}..", "--oneline"])
    if unpushed.returncode == 0 and unpushed.stdout:
        return RepoIssue(repo_path, IssueKind.UNPUSHED)
    return None


@click.group()
def cli() -> None:
    """Inspect local Git repositories."""


@cli.command("check")
@click.option(
    "--search-dir",
    type=click.Path(path_type=Path, file_okay=False),
    default=Path.home() / "dev",
    show_default=True,
)
def check_command(search_dir: Path) -> None:
    """Check Git availability and the repository search root."""
    errors: list[str] = []
    if shutil.which("git") is None:
        errors.append("missing executable: git")
    if not search_dir.expanduser().is_dir():
        errors.append(f"missing directory: {search_dir.expanduser()}")
    if errors:
        for error in errors:
            click.echo(error, err=True)
        raise SystemExit(1)
    click.echo("OK")


@cli.command("scan")
@click.argument(
    "search_dir",
    type=click.Path(path_type=Path, exists=True, file_okay=False),
    default=Path.home() / "dev",
)
def scan_command(search_dir: Path) -> None:
    """Print repositories containing local changes or unpushed commits."""
    configure_logging()
    failures = 0
    for repo_path in repo_paths(search_dir.expanduser()):
        try:
            issue = inspect_repo(repo_path)
        except ScanError as error:
            failures += 1
            logger.error("repo_scan_failed", repo=str(repo_path), reason=str(error))
            continue
        if issue is not None:
            click.echo(f"{issue.kind.value}\t{issue.path}")
    if failures:
        raise click.ClickException(
            f"failed to inspect {failures} repository/repositories"
        )


def compact_pytest_output(output: str) -> str:
    lines = [
        line
        for line in output.splitlines()
        if not (line.startswith("=") and " tests coverage " in line)
        and not (line.startswith("_") and " coverage: platform " in line)
    ]
    return "\n".join(lines).strip() + "\n"


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="find-uncommitted-coverage-") as directory:
        config = Path(directory) / ".coveragerc"
        config.write_text(
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
        previous = os.environ.get("COVERAGE_FILE")
        os.environ["COVERAGE_FILE"] = str(Path(directory) / ".coverage")
        output = io.StringIO()
        try:
            with contextlib.redirect_stdout(output):
                result = pytest.main(
                    [
                        "--cov",
                        "--cov-branch",
                        "--cov-config",
                        str(config),
                        "--cov-report=term-missing",
                        "-p",
                        "no:cacheprovider",
                        __file__,
                        "-q",
                    ]
                )
        finally:
            if previous is None:
                os.environ.pop("COVERAGE_FILE", None)
            else:
                os.environ["COVERAGE_FILE"] = previous
    click.echo(compact_pytest_output(output.getvalue()), nl=False)
    raise SystemExit(result)


cli.add_command(unit_test_command)


def completed(
    returncode: int = 0, stdout: str = "", stderr: str = ""
) -> sp.CompletedProcess[str]:
    return sp.CompletedProcess(["git"], returncode, stdout, stderr)


def test_inspect_repo_states() -> None:
    dirty = lambda _path, _args: completed(stdout=" M file\n")  # noqa: E731
    assert inspect_repo(Path("repo"), dirty) == RepoIssue(
        Path("repo"), IssueKind.UNCOMMITTED
    )
    calls = iter((completed(), completed(stdout="abc commit\n")))
    clean = lambda _path, _args: next(calls)  # noqa: E731
    assert inspect_repo(Path("repo"), clean) == RepoIssue(
        Path("repo"), IssueKind.UNPUSHED
    )


def test_inspect_repo_failure() -> None:
    runner = lambda _path, _args: completed(1, stderr="broken")  # noqa: E731
    with pytest.raises(ScanError, match="broken"):
        inspect_repo(Path("repo"), runner)


def test_repo_paths_and_cli(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    (repo / ".git").mkdir(parents=True)
    assert repo_paths(tmp_path) == [repo]
    result = CliRunner().invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "scan" in result.stdout
    assert "unit-test" in result.stdout
    check = CliRunner().invoke(cli, ["check", "--search-dir", str(tmp_path)])
    assert check.exit_code == 0
    assert check.stdout == "OK\n"
    assert check.stderr == ""


if __name__ == "__main__":
    cli()
