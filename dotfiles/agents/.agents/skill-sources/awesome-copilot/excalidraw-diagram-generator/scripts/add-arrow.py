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

"""Add a standalone arrow and optional label to an Excalidraw diagram."""

from __future__ import annotations

import contextlib
import io
import os
import subprocess as sp
import sys
import tempfile
import uuid
from pathlib import Path

import click
import orjson as json
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from pydantic import BaseModel, ConfigDict, Field, JsonValue, ValidationError

logger = log.get_logger(__name__)


class ArrowError(Exception):
    """Report an expected diagram, input, or filesystem failure."""


class Diagram(BaseModel):
    """Validate the mutable portion while preserving Excalidraw metadata."""

    model_config = ConfigDict(extra="allow")
    elements: list[dict[str, JsonValue]] = Field(default_factory=list)


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


def generate_unique_id() -> str:
    """Return a compact Excalidraw-compatible identifier."""
    return uuid.uuid4().hex[:16]


def create_arrow(
    from_x: float,
    from_y: float,
    to_x: float,
    to_y: float,
    *,
    style: str,
    color: str,
    label: str | None,
) -> list[dict[str, JsonValue]]:
    """Build an Excalidraw arrow and, when requested, its text label."""
    width = to_x - from_x
    height = to_y - from_y
    seed_material = f"{from_x}:{from_y}:{to_x}:{to_y}"
    seed = 1_000_000_000 + hash(seed_material) % 1_000_000_000
    arrow: dict[str, JsonValue] = {
        "id": generate_unique_id(),
        "type": "arrow",
        "x": from_x,
        "y": from_y,
        "width": width,
        "height": height,
        "angle": 0,
        "strokeColor": color,
        "backgroundColor": "transparent",
        "fillStyle": "solid",
        "strokeWidth": 2,
        "strokeStyle": style,
        "roughness": 1,
        "opacity": 100,
        "groupIds": [],
        "frameId": None,
        "index": "a0",
        "roundness": {"type": 2},
        "seed": seed,
        "version": 1,
        "versionNonce": seed + 1_000_000_000,
        "isDeleted": False,
        "boundElements": [],
        "updated": 1_738_195_200_000,
        "link": None,
        "locked": False,
        "points": [[0, 0], [width, height]],
        "startBinding": None,
        "endBinding": None,
        "startArrowhead": None,
        "endArrowhead": "arrow",
        "lastCommittedPoint": None,
    }
    elements: list[dict[str, JsonValue]] = [arrow]
    if label:
        label_seed = 1_000_000_000 + hash(label) % 1_000_000_000
        elements.append(
            {
                "id": generate_unique_id(),
                "type": "text",
                "x": (from_x + to_x) / 2 - len(label) * 5,
                "y": (from_y + to_y) / 2 - 10,
                "width": len(label) * 10,
                "height": 20,
                "angle": 0,
                "strokeColor": color,
                "backgroundColor": "transparent",
                "fillStyle": "solid",
                "strokeWidth": 2,
                "strokeStyle": "solid",
                "roughness": 1,
                "opacity": 100,
                "groupIds": [],
                "frameId": None,
                "index": "a0",
                "roundness": None,
                "seed": label_seed,
                "version": 1,
                "versionNonce": label_seed + 1_000_000_000,
                "isDeleted": False,
                "boundElements": [],
                "updated": 1_738_195_200_000,
                "link": None,
                "locked": False,
                "text": label,
                "fontSize": 14,
                "fontFamily": 5,
                "textAlign": "center",
                "verticalAlign": "top",
                "containerId": None,
                "originalText": label,
                "autoResize": True,
                "lineHeight": 1.25,
            }
        )
    return elements


def add_arrow_to_source(
    source: bytes,
    *,
    from_x: float,
    from_y: float,
    to_x: float,
    to_y: float,
    style: str,
    color: str,
    label: str | None,
) -> tuple[bytes, int]:
    """Validate SOURCE and return the updated document plus its new element count."""
    if from_x == to_x and from_y == to_y:
        raise ArrowError("arrow start and end coordinates must differ")
    if not color.startswith("#") or len(color) not in {4, 7, 9}:
        raise ArrowError("color must be a #RGB, #RRGGBB, or #RRGGBBAA value")
    try:
        diagram = Diagram.model_validate(json.loads(source))
    except (json.JSONDecodeError, ValidationError) as exc:
        raise ArrowError(f"invalid Excalidraw document: {exc}") from exc
    diagram.elements.extend(
        create_arrow(
            from_x,
            from_y,
            to_x,
            to_y,
            style=style,
            color=color,
            label=label,
        )
    )
    payload = json.dumps(
        diagram.model_dump(mode="json"),
        option=json.OPT_INDENT_2 | json.OPT_APPEND_NEWLINE,
    )
    return payload, len(diagram.elements)


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


def commit_edit(path: Path, payload: bytes, *, use_edit_suffix: bool) -> None:
    """Write via an editor-safe suffix and always restore the canonical path."""
    if not use_edit_suffix or path.suffix != ".excalidraw":
        write_atomic(path, payload)
        return
    edit_path = path.with_suffix(".excalidraw.edit")
    if edit_path.exists():
        raise ArrowError(f"edit file already exists: {edit_path}")
    path.rename(edit_path)
    try:
        write_atomic(edit_path, payload)
        os.replace(edit_path, path)
    except OSError:
        if edit_path.exists() and not path.exists():
            os.replace(edit_path, path)
        raise


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
    """Modify Excalidraw diagrams."""
    configure_logging()


@cli.command(name="add")
@click.argument("diagram", type=click.Path(path_type=Path, exists=True, dir_okay=False))
@click.argument("from_x", type=float)
@click.argument("from_y", type=float)
@click.argument("to_x", type=float)
@click.argument("to_y", type=float)
@click.option(
    "--style",
    type=click.Choice(("solid", "dashed", "dotted")),
    default="solid",
    show_default=True,
)
@click.option("--color", default="#1e1e1e", show_default=True)
@click.option("--label")
@click.option("--edit-suffix/--no-edit-suffix", default=True, show_default=True)
@click.option("--dry-run", is_flag=True, help="Validate and describe without writing.")
@click.option("--yes", is_flag=True, help="Write without interactive confirmation.")
def add_command(
    diagram: Path,
    from_x: float,
    from_y: float,
    to_x: float,
    to_y: float,
    style: str,
    color: str,
    label: str | None,
    edit_suffix: bool,
    dry_run: bool,
    yes: bool,
) -> None:
    """Add an arrow between two coordinate pairs in DIAGRAM."""
    try:
        payload, element_count = add_arrow_to_source(
            diagram.read_bytes(),
            from_x=from_x,
            from_y=from_y,
            to_x=to_x,
            to_y=to_y,
            style=style,
            color=color,
            label=label,
        )
    except (OSError, ArrowError) as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would add arrow; resulting element count: {element_count}")
        return
    if not yes:
        click.confirm(f"Modify {diagram}?", abort=True)
    try:
        commit_edit(diagram, payload, use_edit_suffix=edit_suffix)
    except (OSError, ArrowError) as exc:
        raise click.ClickException(f"could not update {diagram}: {exc}") from exc
    logger.info("arrow_added", diagram=str(diagram), element_count=element_count)
    click.echo(element_count)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="excalidraw-arrow-coverage-") as directory:
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


def test_create_arrow_with_and_without_label(monkeypatch: pytest.MonkeyPatch) -> None:
    identifiers = iter(("plain-id", "arrow-id", "label-id"))
    monkeypatch.setattr(
        sys.modules[__name__], "generate_unique_id", lambda: next(identifiers)
    )
    plain = create_arrow(1, 2, 11, 22, style="dashed", color="#fff", label=None)
    assert plain[0]["points"] == [[0, 0], [10, 20]]
    labelled = create_arrow(1, 2, 11, 22, style="solid", color="#000", label="HTTP")
    assert [element["id"] for element in labelled] == ["arrow-id", "label-id"]
    assert labelled[1]["text"] == "HTTP"


@pytest.mark.parametrize(
    ("source", "coordinates", "color", "message"),
    [
        (b"{}", (1.0, 1.0, 1.0, 1.0), "#fff", "must differ"),
        (b"{}", (0.0, 0.0, 1.0, 1.0), "red", "color must"),
        (b"{", (0.0, 0.0, 1.0, 1.0), "#fff", "invalid Excalidraw"),
        (b'{"elements":"bad"}', (0.0, 0.0, 1.0, 1.0), "#fff", "invalid Excalidraw"),
    ],
)
def test_add_arrow_to_source_rejects_bad_input(
    source: bytes,
    coordinates: tuple[float, float, float, float],
    color: str,
    message: str,
) -> None:
    with pytest.raises(ArrowError, match=message):
        add_arrow_to_source(
            source,
            from_x=coordinates[0],
            from_y=coordinates[1],
            to_x=coordinates[2],
            to_y=coordinates[3],
            style="solid",
            color=color,
            label=None,
        )


def test_add_arrow_to_source_preserves_metadata() -> None:
    payload, count = add_arrow_to_source(
        b'{"type":"excalidraw","elements":[]}',
        from_x=0,
        from_y=0,
        to_x=10,
        to_y=20,
        style="solid",
        color="#12345678",
        label="API",
    )
    document = json.loads(payload)
    assert count == 2
    assert document["type"] == "excalidraw"
    assert payload.endswith(b"\n")


def test_commit_edit_direct_and_suffix(tmp_path: Path) -> None:
    direct = tmp_path / "diagram.json"
    direct.write_bytes(b"old")
    commit_edit(direct, b"new", use_edit_suffix=True)
    assert direct.read_bytes() == b"new"
    diagram = tmp_path / "diagram.excalidraw"
    diagram.write_bytes(b"old")
    diagram.chmod(0o640)
    commit_edit(diagram, b"new", use_edit_suffix=True)
    assert diagram.read_bytes() == b"new"
    assert diagram.stat().st_mode & 0o777 == 0o640


def test_commit_edit_rejects_existing_edit_file(tmp_path: Path) -> None:
    diagram = tmp_path / "diagram.excalidraw"
    diagram.write_bytes(b"old")
    diagram.with_suffix(".excalidraw.edit").write_bytes(b"busy")
    with pytest.raises(ArrowError, match="already exists"):
        commit_edit(diagram, b"new", use_edit_suffix=True)


def test_commit_edit_restores_original_on_write_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    diagram = tmp_path / "diagram.excalidraw"
    diagram.write_bytes(b"old")

    def fail(_path: Path, _payload: bytes) -> None:
        raise OSError("disk full")

    monkeypatch.setattr(sys.modules[__name__], "write_atomic", fail)
    with pytest.raises(OSError, match="disk full"):
        commit_edit(diagram, b"new", use_edit_suffix=True)
    assert diagram.read_bytes() == b"old"

    def restore_then_fail(edit_path: Path, _payload: bytes) -> None:
        os.replace(edit_path, diagram)
        raise OSError("late failure")

    monkeypatch.setattr(sys.modules[__name__], "write_atomic", restore_then_fail)
    with pytest.raises(OSError, match="late failure"):
        commit_edit(diagram, b"new", use_edit_suffix=True)
    assert diagram.read_bytes() == b"old"


def test_add_command_dry_run_and_write(tmp_path: Path) -> None:
    diagram = tmp_path / "diagram.excalidraw"
    diagram.write_bytes(b'{"elements":[]}')
    runner = CliRunner()
    dry_run = runner.invoke(cli, ["add", str(diagram), "0", "0", "1", "1", "--dry-run"])
    assert dry_run.exit_code == 0
    assert "Would add arrow" in dry_run.stdout
    assert json.loads(diagram.read_bytes())["elements"] == []
    written = runner.invoke(
        cli,
        ["add", str(diagram), "0", "0", "1", "1", "--label", "API"],
        input="y\n",
    )
    assert written.exit_code == 0
    assert len(json.loads(diagram.read_bytes())["elements"]) == 2


def test_add_command_translates_errors(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    diagram = tmp_path / "diagram.excalidraw"
    diagram.write_bytes(b"{")
    result = CliRunner().invoke(
        cli, ["add", str(diagram), "0", "0", "1", "1", "--dry-run"]
    )
    assert result.exit_code == 1
    assert "invalid Excalidraw" in result.stderr
    diagram.write_bytes(b'{"elements":[]}')

    def fail(_path: Path, _payload: bytes, *, use_edit_suffix: bool) -> None:
        raise OSError(f"write failed: {use_edit_suffix}")

    monkeypatch.setattr(sys.modules[__name__], "commit_edit", fail)
    result = CliRunner().invoke(cli, ["add", str(diagram), "0", "0", "1", "1", "--yes"])
    assert result.exit_code == 1
    assert "write failed" in result.stderr


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
    assert "add" in result.stdout
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
    assert "Modify Excalidraw" in process.stdout


if __name__ == "__main__":
    cli()
