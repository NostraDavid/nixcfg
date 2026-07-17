#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "orjson==3.11.7",
#     "pydantic==2.12.5",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "regex==2026.2.28",
#     "structlog==26.1.0",
# ]
# ///

"""Replace a local plugin version's Codex cachebuster suffix."""

from __future__ import annotations

import contextlib
import datetime as dt
import io
import os
import subprocess as sp
import sys
import tempfile
from pathlib import Path

import click
import orjson as json
import pytest
import regex as re
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from pydantic import BaseModel, ConfigDict, ValidationError, field_validator

CACHEBUSTER_PREFIX = "codex"
logger = log.get_logger(__name__)


class CachebusterError(Exception):
    """Report an expected manifest, value, or write failure."""


class PluginManifest(BaseModel):
    """Validate version while preserving the remaining plugin manifest."""

    model_config = ConfigDict(extra="allow")
    version: str

    @field_validator("version")
    @classmethod
    def version_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("version must not be blank")
        return value.strip()


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


def sanitize_cachebuster(value: str) -> str:
    """Normalize a cachebuster into lowercase hyphen-case."""
    sanitized = re.sub(r"[^a-z0-9-]+", "-", value.strip().lower())
    sanitized = re.sub(r"-{2,}", "-", sanitized).strip("-")
    if not sanitized:
        raise CachebusterError("cachebuster must contain at least one letter or digit")
    return sanitized


def default_cachebuster(now: dt.datetime | None = None) -> str:
    """Return a UTC timestamp cachebuster."""
    instant = now or dt.datetime.now(dt.UTC)
    return instant.astimezone(dt.UTC).strftime("%Y%m%d%H%M%S")


def with_cachebuster(version: str, cachebuster: str) -> str:
    """Replace all existing build metadata with one Codex cachebuster."""
    version_prefix = version.split("+", 1)[0]
    return f"{version_prefix}+{CACHEBUSTER_PREFIX}.{cachebuster}"


def load_manifest(path: Path) -> PluginManifest:
    """Read and validate a plugin manifest."""
    try:
        return PluginManifest.model_validate(json.loads(path.read_bytes()))
    except OSError as exc:
        raise CachebusterError(f"could not read {path}: {exc}") from exc
    except (json.JSONDecodeError, ValidationError) as exc:
        raise CachebusterError(f"invalid plugin manifest {path}: {exc}") from exc


def render_manifest(
    manifest: PluginManifest, cachebuster: str
) -> tuple[bytes, str, str]:
    """Return updated JSON plus the previous and next versions."""
    previous = manifest.version
    next_version = with_cachebuster(previous, sanitize_cachebuster(cachebuster))
    manifest.version = next_version
    payload = json.dumps(
        manifest.model_dump(mode="json"),
        option=json.OPT_INDENT_2 | json.OPT_APPEND_NEWLINE,
    )
    return payload, previous, next_version


def write_atomic(path: Path, payload: bytes) -> None:
    """Replace PATH atomically while retaining its mode bits."""
    mode = path.stat().st_mode
    descriptor, raw_temp_path = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temp_path = Path(raw_temp_path)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_path, mode)
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


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
    """Manage local plugin cachebuster versions."""
    configure_logging()


@cli.command(name="update")
@click.argument(
    "plugin_path", type=click.Path(path_type=Path, exists=True, file_okay=False)
)
@click.option(
    "--cachebuster", help="Token to use instead of the current UTC timestamp."
)
@click.option(
    "--dry-run", is_flag=True, help="Print the version change without writing."
)
@click.option("--yes", is_flag=True, help="Write without interactive confirmation.")
def update_command(
    plugin_path: Path, cachebuster: str | None, dry_run: bool, yes: bool
) -> None:
    """Update .codex-plugin/plugin.json beneath PLUGIN_PATH."""
    manifest_path = plugin_path / ".codex-plugin" / "plugin.json"
    try:
        manifest = load_manifest(manifest_path)
        payload, previous, next_version = render_manifest(
            manifest, cachebuster or default_cachebuster()
        )
    except CachebusterError as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would update plugin version: {previous} -> {next_version}")
        return
    if not yes:
        click.confirm(f"Update {manifest_path}?", abort=True)
    try:
        write_atomic(manifest_path, payload)
    except OSError as exc:
        raise click.ClickException(f"could not update {manifest_path}: {exc}") from exc
    logger.info(
        "plugin_cachebuster_updated",
        manifest=str(manifest_path),
        previous=previous,
        current=next_version,
    )
    click.echo(f"{previous} -> {next_version}")


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(
        prefix="plugin-cachebuster-coverage-"
    ) as directory:
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


def test_cachebuster_helpers() -> None:
    assert sanitize_cachebuster(" Release  42! ") == "release-42"
    with pytest.raises(CachebusterError, match="at least one"):
        sanitize_cachebuster("!!!")
    instant = dt.datetime(2026, 7, 16, 1, 2, 3, tzinfo=dt.UTC)
    assert default_cachebuster(instant) == "20260716010203"
    assert len(default_cachebuster()) == 14
    assert with_cachebuster("1.2.3+old.value", "new") == "1.2.3+codex.new"


def test_load_and_render_manifest(tmp_path: Path) -> None:
    path = tmp_path / "plugin.json"
    path.write_bytes(b'{"name":"sample","version":"1.0.0+old"}')
    payload, previous, current = render_manifest(load_manifest(path), " Fresh Value ")
    assert previous == "1.0.0+old"
    assert current == "1.0.0+codex.fresh-value"
    assert json.loads(payload)["name"] == "sample"
    assert payload.endswith(b"\n")
    path.write_bytes(b"{")
    with pytest.raises(CachebusterError, match="invalid plugin"):
        load_manifest(path)
    path.write_bytes(b'{"version":" "}')
    with pytest.raises(CachebusterError, match="invalid plugin"):
        load_manifest(path)
    path.unlink()
    with pytest.raises(CachebusterError, match="could not read"):
        load_manifest(path)


def test_update_command_dry_run_and_write(tmp_path: Path) -> None:
    manifest = tmp_path / ".codex-plugin" / "plugin.json"
    manifest.parent.mkdir()
    manifest.write_bytes(b'{"version":"1.0.0"}')
    runner = CliRunner()
    dry_run = runner.invoke(
        cli, ["update", str(tmp_path), "--cachebuster", "test", "--dry-run"]
    )
    assert dry_run.exit_code == 0
    assert "Would update" in dry_run.stdout
    written = runner.invoke(
        cli, ["update", str(tmp_path), "--cachebuster", "test"], input="y\n"
    )
    assert written.exit_code == 0
    assert json.loads(manifest.read_bytes())["version"] == "1.0.0+codex.test"


def test_update_command_translates_errors(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    result = CliRunner().invoke(cli, ["update", str(tmp_path), "--dry-run"])
    assert result.exit_code == 1
    assert "could not read" in result.stderr
    manifest = tmp_path / ".codex-plugin" / "plugin.json"
    manifest.parent.mkdir()
    manifest.write_bytes(b'{"version":"1.0.0"}')

    def fail(_path: Path, _payload: bytes) -> None:
        raise OSError("disk full")

    monkeypatch.setattr(sys.modules[__name__], "write_atomic", fail)
    result = CliRunner().invoke(cli, ["update", str(tmp_path), "--yes"])
    assert result.exit_code == 1
    assert "disk full" in result.stderr


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
    assert "update" in result.stdout
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
    assert "Manage local plugin" in process.stdout


if __name__ == "__main__":
    cli()
