#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "orjson==3.11.7",
#     "pydantic==2.12.5",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""Print the top-level name from a plugin marketplace manifest."""

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
from pydantic import BaseModel, ValidationError, field_validator

logger = log.get_logger(__name__)


class MarketplaceError(Exception):
    """Report an expected marketplace read or validation failure."""


class MarketplaceIdentity(BaseModel):
    """Validate the marketplace field used by this command."""

    name: str

    @field_validator("name")
    @classmethod
    def name_must_not_be_blank(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("name must not be blank")
        return normalized


def configure_logging() -> None:
    """Send human-readable structured diagnostics to stderr."""
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


def default_marketplace_path() -> Path:
    """Return the personal marketplace path for the current user."""
    return Path.home() / ".agents" / "plugins" / "marketplace.json"


def read_marketplace_name(path: Path) -> str:
    """Read and validate the marketplace name at PATH."""
    try:
        payload = json.loads(path.read_bytes())
        return MarketplaceIdentity.model_validate(payload).name
    except OSError as exc:
        raise MarketplaceError(f"could not read {path}: {exc}") from exc
    except (json.JSONDecodeError, ValidationError) as exc:
        raise MarketplaceError(f"invalid marketplace manifest {path}: {exc}") from exc


def compact_pytest_output(output: str) -> str:
    """Remove pytest-cov banners while preserving its useful report."""
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
    """Inspect plugin marketplace metadata."""
    configure_logging()


@cli.command(name="read")
@click.option(
    "--marketplace-path",
    type=click.Path(path_type=Path, exists=True, dir_okay=False),
    default=default_marketplace_path,
    show_default=True,
)
def read_command(marketplace_path: Path) -> None:
    """Print the marketplace name."""
    try:
        name = read_marketplace_name(marketplace_path)
    except MarketplaceError as exc:
        raise click.ClickException(str(exc)) from exc
    logger.info("marketplace_name_read", marketplace=str(marketplace_path))
    click.echo(name)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="marketplace-name-coverage-") as directory:
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


def test_read_marketplace_name_success_and_errors(tmp_path: Path) -> None:
    path = tmp_path / "marketplace.json"
    path.write_bytes(b'{"name":" personal "}')
    assert read_marketplace_name(path) == "personal"
    path.write_bytes(b"{")
    with pytest.raises(MarketplaceError, match="invalid marketplace"):
        read_marketplace_name(path)
    path.write_bytes(b'{"name":" "}')
    with pytest.raises(MarketplaceError, match="invalid marketplace"):
        read_marketplace_name(path)
    path.unlink()
    with pytest.raises(MarketplaceError, match="could not read"):
        read_marketplace_name(path)


def test_read_command_success_and_error(tmp_path: Path) -> None:
    path = tmp_path / "marketplace.json"
    path.write_bytes(b'{"name":"personal"}')
    result = CliRunner().invoke(cli, ["read", "--marketplace-path", str(path)])
    assert result.exit_code == 0
    assert result.stdout == "personal\n"
    path.write_bytes(b"[]")
    result = CliRunner().invoke(cli, ["read", "--marketplace-path", str(path)])
    assert result.exit_code == 1
    assert "invalid marketplace" in result.stderr


def test_default_marketplace_path(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    assert (
        default_marketplace_path()
        == tmp_path / ".agents" / "plugins" / "marketplace.json"
    )


def test_compact_pytest_output_filters_only_banners() -> None:
    output = "ok\n===== tests coverage =====\n_____ coverage: platform x _____\nTOTAL"
    assert compact_pytest_output(output) == "ok\nTOTAL\n"
    assert compact_pytest_output("= keep =\n_ keep _") == "= keep =\n_ keep _\n"


@pytest.mark.parametrize("previous", [None, "existing"])
def test_unit_test_command_restores_environment(
    monkeypatch: pytest.MonkeyPatch, previous: str | None
) -> None:
    if previous is None:
        monkeypatch.delenv("COVERAGE_FILE", raising=False)
    else:
        monkeypatch.setenv("COVERAGE_FILE", previous)

    def fake_main(arguments: list[str]) -> pytest.ExitCode:
        assert Path(arguments[arguments.index("--cov-config") + 1]).exists()
        print("===== tests coverage =====")
        print("TOTAL")
        return pytest.ExitCode.OK

    monkeypatch.setattr(pytest, "main", fake_main)
    result = CliRunner().invoke(unit_test_command)
    assert result.exit_code == 0
    assert result.stdout == "TOTAL\n"
    assert os.environ.get("COVERAGE_FILE") == previous


def test_help_logging_and_entrypoint(capsys: pytest.CaptureFixture[str]) -> None:
    result = CliRunner().invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "read" in result.stdout
    assert "unit-test" in result.stdout
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
    assert process.returncode == 0
    assert "Inspect plugin" in process.stdout


if __name__ == "__main__":
    cli()
