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

"""Split one Excalidraw library into validated per-icon JSON files."""

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
from pydantic import BaseModel, ConfigDict, Field, ValidationError

logger = log.get_logger(__name__)


class LibraryError(Exception):
    """Report an expected library or output failure."""


class LibraryItem(BaseModel):
    """Preserve an Excalidraw library item while validating its name."""

    model_config = ConfigDict(extra="allow")
    name: str = "Unnamed"


class LibraryDocument(BaseModel):
    """Validate the top-level Excalidraw library contract."""

    library_items: list[LibraryItem] = Field(alias="libraryItems")


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


def sanitize_filename(name: str) -> str:
    """Return a portable, readable filename stem."""
    normalized = name.replace(" ", "-")
    filtered = "".join(
        character
        for character in normalized
        if character.isalnum() or character in {"_", "-", "."}
    )
    while "--" in filtered:
        filtered = filtered.replace("--", "-")
    return filtered.strip("-") or "Unnamed"


def find_library_file(directory: Path) -> Path:
    """Require exactly one .excalidrawlib file in DIRECTORY."""
    candidates = sorted(directory.glob("*.excalidrawlib"))
    if not candidates:
        raise LibraryError(f"no .excalidrawlib file found in {directory}")
    if len(candidates) > 1:
        raise LibraryError(f"multiple .excalidrawlib files found in {directory}")
    return candidates[0]


def load_library(path: Path) -> LibraryDocument:
    """Parse and validate an Excalidraw library file."""
    try:
        return LibraryDocument.model_validate(json.loads(path.read_bytes()))
    except OSError as exc:
        raise LibraryError(f"could not read {path}: {exc}") from exc
    except (json.JSONDecodeError, ValidationError) as exc:
        raise LibraryError(f"invalid Excalidraw library: {exc}") from exc


def build_outputs(
    library_path: Path, document: LibraryDocument
) -> tuple[dict[Path, bytes], Path]:
    """Build every output in memory and reject filename collisions."""
    icons_dir = library_path.parent / "icons"
    outputs: dict[Path, bytes] = {}
    rows: list[tuple[str, str]] = []
    for item in document.library_items:
        filename = f"{sanitize_filename(item.name)}.json"
        output_path = icons_dir / filename
        if output_path in outputs:
            raise LibraryError(f"multiple icons resolve to filename {filename}")
        outputs[output_path] = json.dumps(
            item.model_dump(mode="json"),
            option=json.OPT_INDENT_2 | json.OPT_APPEND_NEWLINE,
        )
        rows.append((item.name, filename))
    rows.sort(key=lambda row: row[0].casefold())
    reference_path = library_path.parent / "reference.md"
    table_rows: list[str] = []
    for name, filename in rows:
        escaped_name = name.replace("|", "\\|")
        table_rows.append(f"| {escaped_name} | `icons/{filename}` |")
    table = "\n".join(table_rows)
    reference = (
        f"# {library_path.stem} Reference\n\n"
        f"This directory contains {len(rows)} icons extracted from `{library_path.name}`.\n\n"
        "## Available Icons\n\n"
        "| Icon Name | Filename |\n"
        "| --- | --- |\n"
        f"{table}\n\n"
        "## Usage\n\n"
        "Each icon JSON file contains the complete data needed to render that icon in Excalidraw.\n"
    ).encode()
    outputs[reference_path] = reference
    return outputs, reference_path


def write_atomic(path: Path, payload: bytes) -> None:
    """Create or replace PATH atomically."""
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, raw_temp_path = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temp_path = Path(raw_temp_path)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def write_outputs(outputs: dict[Path, bytes], *, force: bool) -> None:
    """Write prepared outputs, refusing accidental replacement by default."""
    existing = [path for path in outputs if path.exists()]
    if existing and not force:
        raise LibraryError(
            f"{len(existing)} output file(s) already exist; pass --force to replace them"
        )
    for path, payload in outputs.items():
        write_atomic(path, payload)


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
    """Manage Excalidraw library assets."""
    configure_logging()


@cli.command(name="split")
@click.argument(
    "library_directory", type=click.Path(path_type=Path, exists=True, file_okay=False)
)
@click.option(
    "--force", is_flag=True, help="Replace existing icon and reference files."
)
@click.option(
    "--dry-run", is_flag=True, help="Validate and list outputs without writing."
)
@click.option("--yes", is_flag=True, help="Write without interactive confirmation.")
def split_command(
    library_directory: Path, force: bool, dry_run: bool, yes: bool
) -> None:
    """Split the sole library in LIBRARY_DIRECTORY."""
    try:
        library_path = find_library_file(library_directory)
        document = load_library(library_path)
        outputs, reference_path = build_outputs(library_path, document)
    except LibraryError as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would write {len(outputs)} files under {library_directory}")
        return
    if not yes:
        click.confirm(
            f"Write {len(outputs)} files under {library_directory}?", abort=True
        )
    try:
        write_outputs(outputs, force=force)
    except (OSError, LibraryError) as exc:
        raise click.ClickException(str(exc)) from exc
    logger.info(
        "library_split",
        library=str(library_path),
        icons=len(document.library_items),
        reference=str(reference_path),
    )
    click.echo(reference_path)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="excalidraw-split-coverage-") as directory:
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


@pytest.mark.parametrize(
    ("name", "expected"),
    [
        ("AWS  Compute!!", "AWS-Compute"),
        ("---", "Unnamed"),
        ("Data_base.v2", "Data_base.v2"),
    ],
)
def test_sanitize_filename(name: str, expected: str) -> None:
    assert sanitize_filename(name) == expected


def test_find_library_file_requires_exactly_one(tmp_path: Path) -> None:
    with pytest.raises(LibraryError, match="no .excalidrawlib"):
        find_library_file(tmp_path)
    first = tmp_path / "first.excalidrawlib"
    first.write_bytes(b"{}")
    assert find_library_file(tmp_path) == first
    (tmp_path / "second.excalidrawlib").write_bytes(b"{}")
    with pytest.raises(LibraryError, match="multiple"):
        find_library_file(tmp_path)


@pytest.mark.parametrize("payload", [b"{", b"{}"])
def test_load_library_rejects_invalid_input(tmp_path: Path, payload: bytes) -> None:
    path = tmp_path / "icons.excalidrawlib"
    path.write_bytes(payload)
    with pytest.raises(LibraryError, match="invalid Excalidraw"):
        load_library(path)
    with pytest.raises(LibraryError, match="could not read"):
        load_library(tmp_path / "missing.excalidrawlib")


def test_build_outputs_sorts_and_escapes_reference(tmp_path: Path) -> None:
    library_path = tmp_path / "cloud.excalidrawlib"
    document = LibraryDocument.model_validate(
        {
            "libraryItems": [
                {"name": "Zed", "elements": []},
                {"name": "A|B", "elements": []},
            ]
        }
    )
    outputs, reference_path = build_outputs(library_path, document)
    reference = outputs[reference_path].decode()
    assert reference.index("A\\|B") < reference.index("Zed")
    assert outputs[tmp_path / "icons" / "A B.json".replace(" ", "")].endswith(b"\n")


def test_build_outputs_rejects_sanitized_collision(tmp_path: Path) -> None:
    document = LibraryDocument.model_validate(
        {"libraryItems": [{"name": "A B"}, {"name": "A--B"}]}
    )
    with pytest.raises(LibraryError, match="multiple icons"):
        build_outputs(tmp_path / "icons.excalidrawlib", document)


def test_write_outputs_requires_force_and_writes(tmp_path: Path) -> None:
    target = tmp_path / "nested" / "icon.json"
    outputs = {target: b"new"}
    write_outputs(outputs, force=False)
    assert target.read_bytes() == b"new"
    with pytest.raises(LibraryError, match="--force"):
        write_outputs(outputs, force=False)
    write_outputs({target: b"updated"}, force=True)
    assert target.read_bytes() == b"updated"


def test_split_command_dry_run_and_write(tmp_path: Path) -> None:
    library = tmp_path / "cloud.excalidrawlib"
    library.write_bytes(b'{"libraryItems":[{"name":"Compute","elements":[]}]}')
    runner = CliRunner()
    dry_run = runner.invoke(cli, ["split", str(tmp_path), "--dry-run"])
    assert dry_run.exit_code == 0
    assert "Would write 2 files" in dry_run.stdout
    result = runner.invoke(cli, ["split", str(tmp_path)], input="y\n")
    assert result.exit_code == 0
    assert (tmp_path / "icons" / "Compute.json").exists()


def test_split_command_translates_domain_and_write_errors(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    result = CliRunner().invoke(cli, ["split", str(tmp_path), "--dry-run"])
    assert result.exit_code == 1
    assert "no .excalidrawlib" in result.stderr
    library = tmp_path / "cloud.excalidrawlib"
    library.write_bytes(b'{"libraryItems":[]}')

    def fail(_outputs: dict[Path, bytes], *, force: bool) -> None:
        raise OSError(f"disk full: {force}")

    monkeypatch.setattr(sys.modules[__name__], "write_outputs", fail)
    result = CliRunner().invoke(cli, ["split", str(tmp_path), "--yes"])
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
    assert "split" in result.stdout
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
    assert "Manage Excalidraw" in process.stdout


if __name__ == "__main__":
    cli()
