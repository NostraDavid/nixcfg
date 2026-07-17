#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "niquests==3.20.1",
#     "orjson==3.11.7",
#     "pydantic==2.12.5",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""List installable skills from a GitHub repository path."""

from __future__ import annotations

import contextlib
import io
import os
import subprocess as sp
import sys
import tempfile
from pathlib import Path

import click
import orjson as json
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from github_utils import GitHubRequestError, github_api_contents_url, github_request
from pydantic import BaseModel, TypeAdapter, ValidationError

DEFAULT_REPO = "openai/skills"
DEFAULT_PATH = "skills/.curated"
DEFAULT_REF = "main"
logger = log.get_logger(__name__)


class ListError(Exception):
    """Report an expected GitHub response or listing failure."""


class ContentItem(BaseModel):
    """Describe fields used from one GitHub contents item."""

    name: str
    type: str


CONTENTS_ADAPTER = TypeAdapter(list[ContentItem])


def configure_logging() -> None:
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


def codex_home() -> Path:
    """Return CODEX_HOME or its conventional default."""
    return Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))


def installed_skills(root: Path | None = None) -> set[str]:
    """Return directory names already installed under Codex."""
    skills_root = root or codex_home() / "skills"
    if not skills_root.is_dir():
        return set()
    return {entry.name for entry in skills_root.iterdir() if entry.is_dir()}


def list_skills(repo: str, path: str, ref: str) -> list[str]:
    """Fetch and validate a GitHub contents directory listing."""
    url = github_api_contents_url(repo, path, ref)
    try:
        payload = github_request(url, "codex-skill-list")
    except GitHubRequestError as exc:
        if exc.status_code == 404:
            raise ListError(
                f"skills path not found: https://github.com/{repo}/tree/{ref}/{path}"
            ) from exc
        raise ListError(str(exc)) from exc
    try:
        items = CONTENTS_ADAPTER.validate_python(json.loads(payload))
    except (json.JSONDecodeError, ValidationError) as exc:
        raise ListError(f"unexpected skills listing response: {exc}") from exc
    return sorted(item.name for item in items if item.type == "dir")


def render_listing(skills: list[str], installed: set[str], output_format: str) -> str:
    """Render a stable text or JSON listing."""
    if output_format == "json":
        return json.dumps(
            [{"name": name, "installed": name in installed} for name in skills],
            option=json.OPT_APPEND_NEWLINE,
        ).decode()
    return "".join(
        f"{index}. {name}{' (already installed)' if name in installed else ''}\n"
        for index, name in enumerate(skills, start=1)
    )


def compact_pytest_output(output: str) -> str:
    lines: list[str] = []
    for line in output.splitlines():
        section = (
            line.startswith("=") and line.endswith("=") and " tests coverage " in line
        )
        platform = (
            line.startswith("_")
            and line.endswith("_")
            and " coverage: platform " in line
        )
        if not section and not platform:
            lines.append(line)
    return "\n".join(lines).strip() + "\n"


@click.group()
def cli() -> None:
    """Discover installable Codex skills."""
    configure_logging()


@cli.command(name="list")
@click.option("--repo", default=DEFAULT_REPO, show_default=True)
@click.option("--path", "repo_path", default=DEFAULT_PATH, show_default=True)
@click.option("--ref", default=DEFAULT_REF, show_default=True)
@click.option(
    "--format", "output_format", type=click.Choice(("text", "json")), default="text"
)
def list_command(repo: str, repo_path: str, ref: str, output_format: str) -> None:
    """List skill directories and mark installed entries."""
    try:
        skills = list_skills(repo, repo_path, ref)
    except ListError as exc:
        raise click.ClickException(str(exc)) from exc
    logger.info("skills_listed", repo=repo, path=repo_path, count=len(skills))
    click.echo(render_listing(skills, installed_skills(), output_format), nl=False)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="skill-list-coverage-") as directory:
        config = Path(directory) / ".coveragerc"
        config.write_text(
            os.linesep.join(
                (
                    "[run]",
                    "patch = subprocess",
                    "include =",
                    f"    {Path(__file__).resolve()}",
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


def test_installed_skills_and_codex_home(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("CODEX_HOME", str(tmp_path))
    assert codex_home() == tmp_path
    assert installed_skills() == set()
    skills = tmp_path / "skills"
    skills.mkdir()
    skills.joinpath("one").mkdir()
    skills.joinpath("file").write_text("x", encoding="utf-8")
    assert installed_skills() == {"one"}


def test_list_skills_success_and_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        sys.modules[__name__],
        "github_request",
        lambda *_args: (
            b'[{"name":"b","type":"dir"},{"name":"a","type":"dir"},{"name":"f","type":"file"}]'
        ),
    )
    assert list_skills("owner/repo", "skills", "main") == ["a", "b"]

    def not_found(*_args: object) -> bytes:
        raise GitHubRequestError("missing", 404)

    monkeypatch.setattr(sys.modules[__name__], "github_request", not_found)
    with pytest.raises(ListError, match="path not found"):
        list_skills("owner/repo", "skills", "main")

    def failed(*_args: object) -> bytes:
        raise GitHubRequestError("offline")

    monkeypatch.setattr(sys.modules[__name__], "github_request", failed)
    with pytest.raises(ListError, match="offline"):
        list_skills("owner/repo", "skills", "main")
    monkeypatch.setattr(sys.modules[__name__], "github_request", lambda *_args: b"{}")
    with pytest.raises(ListError, match="unexpected"):
        list_skills("owner/repo", "skills", "main")


def test_render_listing() -> None:
    assert (
        render_listing(["a", "b"], {"b"}, "text") == "1. a\n2. b (already installed)\n"
    )
    assert json.loads(render_listing(["a"], {"a"}, "json")) == [
        {"name": "a", "installed": True}
    ]


def test_list_command_success_and_error(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(sys.modules[__name__], "list_skills", lambda *_args: ["a"])
    monkeypatch.setattr(sys.modules[__name__], "installed_skills", lambda: {"a"})
    result = CliRunner().invoke(cli, ["list", "--format", "json"])
    assert result.exit_code == 0 and '"installed":true' in result.stdout

    def fail(*_args: object) -> list[str]:
        raise ListError("failed")

    monkeypatch.setattr(sys.modules[__name__], "list_skills", fail)
    result = CliRunner().invoke(cli, ["list"])
    assert result.exit_code == 1 and "failed" in result.stderr


def test_compact_and_harness(monkeypatch: pytest.MonkeyPatch) -> None:
    assert (
        compact_pytest_output(
            "ok\n===== tests coverage =====\n_____ coverage: platform x _____\nTOTAL"
        )
        == "ok\nTOTAL\n"
    )
    assert compact_pytest_output("= keep =\n_ keep _") == "= keep =\n_ keep _\n"
    monkeypatch.delenv("COVERAGE_FILE", raising=False)

    def fake_main(arguments: list[str]) -> pytest.ExitCode:
        assert Path(arguments[arguments.index("--cov-config") + 1]).exists()
        print("TOTAL")
        return pytest.ExitCode.OK

    monkeypatch.setattr(pytest, "main", fake_main)
    assert CliRunner().invoke(unit_test_command).stdout == "TOTAL\n"


def test_harness_restores_existing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("COVERAGE_FILE", "existing")
    monkeypatch.setattr(pytest, "main", lambda _arguments: pytest.ExitCode.OK)
    assert CliRunner().invoke(unit_test_command).exit_code == 0
    assert os.environ["COVERAGE_FILE"] == "existing"


def test_help_logging_and_entrypoint(capsys: pytest.CaptureFixture[str]) -> None:
    assert "unit-test" in CliRunner().invoke(cli, ["--help"]).stdout
    configure_logging()
    logger.info("test_event")
    assert "test_event" in capsys.readouterr().err
    process = sp.run(
        [sys.executable, __file__, "--help"],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert process.returncode == 0 and "Discover installable" in process.stdout


if __name__ == "__main__":
    cli()
