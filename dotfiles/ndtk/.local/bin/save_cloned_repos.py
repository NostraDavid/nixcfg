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

"""Save credential-free origin URLs for locally cloned Git repositories."""

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
from urllib.parse import urlsplit, urlunsplit

import click
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner

logger = log.get_logger(__name__)
OriginReader = Callable[[Path], str | None]
REMOTE_URL_RE = re.compile(r"^(?:(?:https?|ssh|git|file)://|[^@\s]+@[^:\s]+:)")


class SaveReposError(Exception):
    """Report an expected repository inventory failure."""


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


def repo_paths(search_dir: Path) -> list[Path]:
    paths: list[Path] = []
    for root, directories, files in os.walk(search_dir):
        if ".git" in directories:
            paths.append(Path(root))
            directories.remove(".git")
        elif ".git" in files:
            paths.append(Path(root))
    return sorted(paths)


def origin_url(repo_path: Path) -> str | None:
    result = sp.run(  # noqa: S603 - fixed executable and argument vector
        ["git", "-C", str(repo_path), "remote", "get-url", "origin"],  # noqa: S607
        check=False,
        text=True,
        capture_output=True,
        timeout=30,
    )
    value = result.stdout.strip()
    return value if result.returncode == 0 and value else None


def without_credentials(url: str) -> str:
    if "://" not in url:
        return url
    parts = urlsplit(url)
    hostname = parts.hostname
    if hostname is None:
        return url
    host = f"[{hostname}]" if ":" in hostname else hostname
    netloc = f"{host}:{parts.port}" if parts.port is not None else host
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))


def collect_urls(search_dir: Path, reader: OriginReader = origin_url) -> list[str]:
    urls: set[str] = set()
    for repo_path in repo_paths(search_dir):
        value = reader(repo_path)
        if value and REMOTE_URL_RE.match(value):
            urls.add(without_credentials(value))
    return sorted(urls, key=str.casefold)


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


@click.group()
def cli() -> None:
    """Inventory origins beneath a local project directory."""


@cli.command("check")
@click.option(
    "--search-dir",
    type=click.Path(path_type=Path, file_okay=False),
    default=Path.home() / "dev",
    show_default=True,
)
def check_command(search_dir: Path) -> None:
    """Check Git and read access to the inventory root."""
    errors: list[str] = []
    root = search_dir.expanduser()
    if shutil.which("git") is None:
        errors.append("missing executable: git")
    if not root.is_dir():
        errors.append(f"missing directory: {root}")
    elif not os.access(root, os.R_OK | os.X_OK):
        errors.append(f"directory is not readable: {root}")
    if errors:
        for error in errors:
            click.echo(error, err=True)
        raise SystemExit(1)
    click.echo("OK")


@cli.command("save")
@click.argument(
    "search_dir",
    type=click.Path(path_type=Path, exists=True, file_okay=False),
    default=Path.home() / "dev",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path, dir_okay=False),
    help="Destination file; defaults to SEARCH_DIR/repos.dat.",
)
@click.option("--dry-run", is_flag=True, help="Print the inventory without writing it.")
@click.option(
    "--yes", is_flag=True, help="Overwrite an existing inventory without confirmation."
)
def save_command(
    search_dir: Path, output: Path | None, dry_run: bool, yes: bool
) -> None:
    """Discover origins and save one sanitized URL per line."""
    configure_logging()
    destination = output.expanduser() if output else search_dir / "repos.dat"
    urls = collect_urls(search_dir.expanduser())
    content = "".join(f"{url}\n" for url in urls)
    if dry_run:
        click.echo(content, nl=False)
        return
    if destination.exists() and not yes:
        click.confirm(f"Replace {destination}?", abort=True)
    try:
        atomic_write(destination, content)
    except OSError as error:
        raise click.ClickException(f"cannot write {destination}: {error}") from error
    click.echo(f"saved {len(urls)} repository URL(s) to {destination}")


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
    with tempfile.TemporaryDirectory(prefix="save-repos-coverage-") as directory:
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
        captured = io.StringIO()
        try:
            with contextlib.redirect_stdout(captured):
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
    click.echo(compact_pytest_output(captured.getvalue()), nl=False)
    raise SystemExit(result)


cli.add_command(unit_test_command)


def test_without_credentials() -> None:
    assert (
        without_credentials("https://user:secret@example.test/repo.git")
        == "https://example.test/repo.git"
    )
    assert (
        without_credentials("git@example.test:team/repo.git")
        == "git@example.test:team/repo.git"
    )


def test_collect_urls(tmp_path: Path) -> None:
    first, second = tmp_path / "a", tmp_path / "b"
    (first / ".git").mkdir(parents=True)
    second.mkdir()
    (second / ".git").write_text("gitdir: elsewhere", encoding="utf-8")
    values = {
        first: "https://user:secret@example.test/z.git",
        second: "git@example.test:a.git",
    }
    assert collect_urls(tmp_path, values.get) == [
        "git@example.test:a.git",
        "https://example.test/z.git",
    ]


def test_save_dry_run(tmp_path: Path) -> None:
    result = CliRunner().invoke(cli, ["save", str(tmp_path), "--dry-run"])
    assert result.exit_code == 0
    assert not (tmp_path / "repos.dat").exists()


def test_help() -> None:
    result = CliRunner().invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "save" in result.stdout
    assert "unit-test" in result.stdout


def test_check_success_is_exactly_ok(tmp_path: Path) -> None:
    result = CliRunner().invoke(cli, ["check", "--search-dir", str(tmp_path)])
    assert result.exit_code == 0
    assert result.stdout == "OK\n"
    assert result.stderr == ""


if __name__ == "__main__":
    cli()
