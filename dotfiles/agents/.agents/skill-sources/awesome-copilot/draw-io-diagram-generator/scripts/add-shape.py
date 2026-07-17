#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "defusedxml==0.7.1",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""Add a vertex to an uncompressed draw.io diagram safely."""

from __future__ import annotations

import contextlib
import io
import os
import subprocess as sp
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any

import click
import defusedxml.ElementTree as ET
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner

DEFAULT_STYLE = "rounded=1;whiteSpace=wrap;html=1;"
logger = log.get_logger(__name__)


class DiagramError(Exception):
    """Report an expected draw.io input or mutation failure."""


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


def parse_diagram(source: bytes, diagram_index: int) -> tuple[Any, Any, str]:
    """Return the document root, graph root, and selected page name."""
    if diagram_index < 0:
        raise DiagramError("diagram index must be zero or greater")
    try:
        document = ET.fromstring(source)
    except ET.ParseError as exc:
        raise DiagramError(f"invalid draw.io XML: {exc}") from exc
    if document.tag != "mxfile":
        raise DiagramError(f"root element must be <mxfile>, got <{document.tag}>")
    diagrams = document.findall("diagram")
    if diagram_index >= len(diagrams):
        raise DiagramError(
            f"diagram index {diagram_index} is out of range for {len(diagrams)} page(s)"
        )
    diagram = diagrams[diagram_index]
    graph_model = diagram.find("mxGraphModel")
    if graph_model is None:
        raise DiagramError("compressed draw.io pages are not supported")
    graph_root = graph_model.find("root")
    if graph_root is None:
        raise DiagramError("selected page has no <root> element")
    return document, graph_root, diagram.get("name", str(diagram_index))


def select_parent_id(graph_root: Any) -> str:
    """Prefer the standard layer and fall back to the first non-root cell."""
    cells = graph_root.findall("mxCell")
    identifiers = {cell.get("id") for cell in cells if cell.get("id")}
    if "1" in identifiers:
        return "1"
    for cell in cells:
        identifier = cell.get("id")
        if identifier and identifier != "0":
            return identifier
    raise DiagramError("selected page has no usable parent layer")


def create_cell(
    *,
    identifier: str,
    parent_id: str,
    label: str,
    x: int,
    y: int,
    width: int,
    height: int,
    style: str,
) -> Any:
    """Build one mxCell without interpolating untrusted text into XML."""
    cell = ET.fromstring("<mxCell><mxGeometry /></mxCell>")
    for key, value in {
        "id": identifier,
        "value": label,
        "style": style,
        "vertex": "1",
        "parent": parent_id,
    }.items():
        cell.set(key, value)
    geometry = cell.find("mxGeometry")
    if geometry is None:  # pragma: no cover - constant template invariant
        raise DiagramError("internal shape template is invalid")
    for key, value in {
        "x": x,
        "y": y,
        "width": width,
        "height": height,
        "as": "geometry",
    }.items():
        geometry.set(key, str(value))
    return cell


def add_shape_to_source(
    source: bytes,
    *,
    label: str,
    x: int,
    y: int,
    width: int,
    height: int,
    style: str,
    diagram_index: int,
    identifier: str,
) -> tuple[bytes, str]:
    """Return updated XML and the selected page name."""
    if width <= 0 or height <= 0:
        raise DiagramError("width and height must be greater than zero")
    if not label.strip():
        raise DiagramError("label must not be empty")
    document, graph_root, page_name = parse_diagram(source, diagram_index)
    existing_ids = {
        cell.get("id") for cell in graph_root.findall("mxCell") if cell.get("id")
    }
    if identifier in existing_ids:
        raise DiagramError(f"generated cell id already exists: {identifier}")
    graph_root.append(
        create_cell(
            identifier=identifier,
            parent_id=select_parent_id(graph_root),
            label=label,
            x=x,
            y=y,
            width=width,
            height=height,
            style=style,
        )
    )
    return b'<?xml version="1.0" encoding="utf-8"?>\n' + ET.tostring(
        document, encoding="utf-8"
    ), page_name


def write_atomic(path: Path, payload: bytes) -> None:
    """Replace PATH atomically while preserving its permission bits."""
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
    lines: list[str] = []
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


@click.group()
def cli() -> None:
    """Modify uncompressed draw.io diagrams."""
    configure_logging()


@cli.command(name="add")
@click.argument("diagram", type=click.Path(path_type=Path, exists=True, dir_okay=False))
@click.argument("label")
@click.argument("x", type=int)
@click.argument("y", type=int)
@click.option("--width", type=click.IntRange(min=1), default=120, show_default=True)
@click.option("--height", type=click.IntRange(min=1), default=60, show_default=True)
@click.option("--style", default=DEFAULT_STYLE, show_default=True)
@click.option(
    "--diagram-index", type=click.IntRange(min=0), default=0, show_default=True
)
@click.option(
    "--dry-run", is_flag=True, help="Validate and print the candidate cell only."
)
@click.option("--yes", is_flag=True, help="Modify the diagram without confirmation.")
def add_command(
    diagram: Path,
    label: str,
    x: int,
    y: int,
    width: int,
    height: int,
    style: str,
    diagram_index: int,
    dry_run: bool,
    yes: bool,
) -> None:
    """Add a shape to DIAGRAM at X and Y."""
    identifier = f"auto_{uuid.uuid4().hex[:12]}"
    try:
        updated, page_name = add_shape_to_source(
            diagram.read_bytes(),
            label=label,
            x=x,
            y=y,
            width=width,
            height=height,
            style=style,
            diagram_index=diagram_index,
            identifier=identifier,
        )
    except (OSError, DiagramError) as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would add {identifier} to page {page_name} in {diagram}")
        return
    if not yes:
        click.confirm(f"Modify {diagram}?", abort=True)
    try:
        write_atomic(diagram, updated)
    except OSError as exc:
        raise click.ClickException(f"could not update {diagram}: {exc}") from exc
    logger.info("shape_added", diagram=str(diagram), page=page_name, cell_id=identifier)
    click.echo(identifier)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="drawio-add-shape-coverage-") as directory:
        coverage_config = Path(directory) / ".coveragerc"
        coverage_config.write_text(
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
                        str(coverage_config),
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


def sample_diagram() -> bytes:
    return b"""<mxfile><diagram name="Main"><mxGraphModel><root>
<mxCell id="0"/><mxCell id="1" parent="0"/>
</root></mxGraphModel></diagram></mxfile>"""


def test_add_shape_to_source() -> None:
    updated, page = add_shape_to_source(
        sample_diagram(),
        label="A & B",
        x=10,
        y=20,
        width=30,
        height=40,
        style=DEFAULT_STYLE,
        diagram_index=0,
        identifier="auto_test",
    )
    assert page == "Main"
    assert b"A &amp; B" in updated
    assert b'id="auto_test"' in updated


@pytest.mark.parametrize(
    ("source", "index", "message"),
    [
        (b"<other/>", 0, "root element"),
        (b"<mxfile/>", 0, "out of range"),
        (sample_diagram(), -1, "zero or greater"),
    ],
)
def test_parse_diagram_errors(source: bytes, index: int, message: str) -> None:
    with pytest.raises(DiagramError, match=message):
        parse_diagram(source, index)


def test_parse_diagram_rejects_invalid_xml() -> None:
    with pytest.raises(DiagramError, match="invalid draw.io XML"):
        parse_diagram(b"<bad>", 0)


def test_parse_diagram_rejects_compressed_and_incomplete_pages() -> None:
    with pytest.raises(DiagramError, match="compressed"):
        parse_diagram(b"<mxfile><diagram /></mxfile>", 0)
    with pytest.raises(DiagramError, match="no <root>"):
        parse_diagram(b"<mxfile><diagram><mxGraphModel /></diagram></mxfile>", 0)


def test_parse_diagram_uses_index_as_unnamed_page_name() -> None:
    source = sample_diagram().replace(b' name="Main"', b"")
    _, _, page_name = parse_diagram(source, 0)
    assert page_name == "0"


def test_select_parent_id_falls_back_and_rejects_root_only() -> None:
    _, graph_root, _ = parse_diagram(
        b"<mxfile><diagram><mxGraphModel><root>"
        b'<mxCell id="0"/><mxCell id="layer"/>'
        b"</root></mxGraphModel></diagram></mxfile>",
        0,
    )
    assert select_parent_id(graph_root) == "layer"

    _, root_only, _ = parse_diagram(
        b"<mxfile><diagram><mxGraphModel><root>"
        b'<mxCell id="0"/>'
        b"</root></mxGraphModel></diagram></mxfile>",
        0,
    )
    with pytest.raises(DiagramError, match="no usable parent"):
        select_parent_id(root_only)


@pytest.mark.parametrize(
    ("label", "width", "height", "message"),
    [
        ("Node", 0, 10, "greater than zero"),
        ("Node", 10, 0, "greater than zero"),
        ("  ", 10, 10, "must not be empty"),
    ],
)
def test_add_shape_validates_dimensions_and_label(
    label: str, width: int, height: int, message: str
) -> None:
    with pytest.raises(DiagramError, match=message):
        add_shape_to_source(
            sample_diagram(),
            label=label,
            x=0,
            y=0,
            width=width,
            height=height,
            style=DEFAULT_STYLE,
            diagram_index=0,
            identifier="candidate",
        )


def test_add_shape_rejects_duplicate_identifier() -> None:
    with pytest.raises(DiagramError, match="already exists"):
        add_shape_to_source(
            sample_diagram(),
            label="Node",
            x=0,
            y=0,
            width=10,
            height=10,
            style=DEFAULT_STYLE,
            diagram_index=0,
            identifier="1",
        )


def test_add_command_dry_run(tmp_path: Path) -> None:
    target = tmp_path / "diagram.drawio"
    target.write_bytes(sample_diagram())
    result = CliRunner().invoke(
        cli, ["add", str(target), "Node", "1", "2", "--dry-run"]
    )
    assert result.exit_code == 0
    assert "Would add" in result.output
    assert target.read_bytes() == sample_diagram()


def test_add_command_writes_atomically(tmp_path: Path) -> None:
    target = tmp_path / "diagram.drawio"
    target.write_bytes(sample_diagram())
    target.chmod(0o640)
    result = CliRunner().invoke(cli, ["add", str(target), "Node", "1", "2", "--yes"])
    assert result.exit_code == 0
    assert b"Node" in target.read_bytes()
    assert target.stat().st_mode & 0o777 == 0o640


def test_add_command_confirms_mutation(tmp_path: Path) -> None:
    target = tmp_path / "diagram.drawio"
    target.write_bytes(sample_diagram())
    result = CliRunner().invoke(
        cli, ["add", str(target), "Node", "1", "2"], input="y\n"
    )
    assert result.exit_code == 0
    assert "Modify" in result.output


def test_add_command_translates_domain_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    target = tmp_path / "diagram.drawio"
    target.write_bytes(sample_diagram())

    def fail(*_args: object, **_kwargs: object) -> tuple[bytes, str]:
        raise DiagramError("broken diagram")

    monkeypatch.setattr(sys.modules[__name__], "add_shape_to_source", fail)
    result = CliRunner().invoke(
        cli, ["add", str(target), "Node", "1", "2", "--dry-run"]
    )
    assert result.exit_code == 1
    assert "broken diagram" in result.stderr


def test_add_command_translates_write_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    target = tmp_path / "diagram.drawio"
    target.write_bytes(sample_diagram())

    def fail(_path: Path, _payload: bytes) -> None:
        raise OSError("disk full")

    monkeypatch.setattr(sys.modules[__name__], "write_atomic", fail)
    result = CliRunner().invoke(cli, ["add", str(target), "Node", "1", "2", "--yes"])
    assert result.exit_code == 1
    assert "disk full" in result.stderr


def test_compact_pytest_output_removes_only_coverage_banners() -> None:
    output = "\n".join(
        (
            "... [100%]",
            "===== tests coverage =====",
            "_____ coverage: platform linux, python 3.14 _____",
            "TOTAL 1 0 100%",
        )
    )
    assert compact_pytest_output(output) == "... [100%]\nTOTAL 1 0 100%\n"


@pytest.mark.parametrize(
    "line",
    ["= incomplete", "= unrelated =", "_ incomplete", "_ unrelated _"],
)
def test_compact_pytest_output_preserves_similar_lines(line: str) -> None:
    assert compact_pytest_output(line) == f"{line}\n"


@pytest.mark.parametrize("previous", [None, "existing-coverage"])
def test_unit_test_command_restores_environment(
    monkeypatch: pytest.MonkeyPatch, previous: str | None
) -> None:
    if previous is None:
        monkeypatch.delenv("COVERAGE_FILE", raising=False)
    else:
        monkeypatch.setenv("COVERAGE_FILE", previous)

    def fake_main(arguments: list[str]) -> pytest.ExitCode:
        config = Path(arguments[arguments.index("--cov-config") + 1])
        assert "patch = subprocess" in config.read_text(encoding="utf-8")
        assert Path(os.environ["COVERAGE_FILE"]).name == ".coverage"
        print("===== tests coverage =====")
        print("TOTAL 1 0 100%")
        return pytest.ExitCode.OK

    monkeypatch.setattr(pytest, "main", fake_main)
    result = CliRunner().invoke(unit_test_command)
    assert result.exit_code == 0
    assert result.stdout == "TOTAL 1 0 100%\n"
    assert os.environ.get("COVERAGE_FILE") == previous


def test_help_lists_commands() -> None:
    result = CliRunner().invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "add" in result.output
    assert "unit-test" in result.output


def test_logging_uses_stderr(capsys: pytest.CaptureFixture[str]) -> None:
    configure_logging()
    logger.info("test_event", value=1)
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "test_event" in captured.err


def test_script_entrypoint_shows_help() -> None:
    result = sp.run(
        [sys.executable, __file__, "--help"],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 0
    assert "Modify uncompressed" in result.stdout


if __name__ == "__main__":
    cli()
