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

"""Validate the structure and references in uncompressed draw.io diagrams."""

from __future__ import annotations

import contextlib
import io
import os
import subprocess as sp
import sys
import tempfile
from pathlib import Path
from typing import Any

import click
import defusedxml.ElementTree as ET
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner

logger = log.get_logger(__name__)


class DiagramValidationError(Exception):
    """Report an expected read or XML validation failure."""


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


def is_title_style(style: str) -> bool:
    """Recognize the title convention used by the draw.io skill."""
    return (style.startswith("text;") or ";text;" in style) and "fontSize=18" in style


def endpoint_exists(cell: Any, name: str, cell_ids: set[str]) -> bool:
    """Accept a referenced endpoint or a matching floating-edge point."""
    endpoint = cell.get(name)
    if endpoint is not None:
        return endpoint in cell_ids
    geometry = cell.find("mxGeometry")
    return geometry is not None and any(
        point.get("as") == f"{name}Point" for point in geometry.findall("mxPoint")
    )


def validate_cells(cells: list[Any], page_name: str) -> list[str]:
    """Return structural errors for the cells on one page."""
    prefix = f"[diagram '{page_name}']"
    errors: list[str] = []
    cell_ids: set[str] = set()
    for cell in cells:
        identifier = cell.get("id")
        if identifier is None:
            errors.append(f"{prefix} Found <mxCell> without an 'id' attribute")
        elif identifier in cell_ids:
            errors.append(f"{prefix} Duplicate cell id='{identifier}'")
        else:
            cell_ids.add(identifier)

    for required, description in (("0", "root"), ("1", "default-layer")):
        if required not in cell_ids:
            errors.append(
                f"{prefix} Missing required {description} cell id='{required}'"
            )
    for index, expected in enumerate(("0", "1")):
        if len(cells) > index and cells[index].get("id") != expected:
            errors.append(
                f"{prefix} Cell {index + 1} must have id='{expected}', "
                f"got id='{cells[index].get('id')}'"
            )
    layer = next((cell for cell in cells if cell.get("id") == "1"), None)
    if layer is not None and layer.get("parent") != "0":
        errors.append(f"{prefix} Cell id='1' must have parent='0'")
    if not any(
        cell.get("vertex") == "1" and is_title_style(cell.get("style") or "")
        for cell in cells
    ):
        errors.append(f"{prefix} No title cell with text style and fontSize=18")

    for cell in cells:
        identifier = cell.get("id", "<unknown>")
        parent = cell.get("parent")
        if identifier != "0" and (parent is None or parent not in cell_ids):
            errors.append(f"{prefix} Cell id='{identifier}' has an invalid parent")
        if cell.get("vertex") == "1" and cell.find("mxGeometry") is None:
            errors.append(
                f"{prefix} Vertex cell id='{identifier}' is missing <mxGeometry>"
            )
        if cell.get("edge") == "1":
            for endpoint in ("source", "target"):
                if not endpoint_exists(cell, endpoint, cell_ids):
                    errors.append(
                        f"{prefix} Edge cell id='{identifier}' has an invalid {endpoint}"
                    )
    return errors


def validate_source(source: bytes) -> tuple[list[str], list[str]]:
    """Return validation errors and names of compressed pages that were skipped."""
    try:
        root = ET.fromstring(source)
    except ET.ParseError as exc:
        raise DiagramValidationError(f"invalid draw.io XML: {exc}") from exc
    if root.tag != "mxfile":
        raise DiagramValidationError(f"root element must be <mxfile>, got <{root.tag}>")
    diagrams = root.findall("diagram")
    if not diagrams:
        raise DiagramValidationError("no <diagram> pages found")

    errors: list[str] = []
    skipped: list[str] = []
    for index, diagram in enumerate(diagrams):
        page_name = diagram.get("name", f"page-{index}")
        graph_model = diagram.find("mxGraphModel")
        if graph_model is None:
            skipped.append(page_name)
            continue
        graph_root = graph_model.find("root")
        if graph_root is None:
            errors.append(f"[diagram '{page_name}'] Missing <root> in <mxGraphModel>")
            continue
        errors.extend(validate_cells(graph_root.findall("mxCell"), page_name))
    return errors, skipped


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
    """Inspect draw.io diagrams without modifying them."""
    configure_logging()


@cli.command(name="validate")
@click.argument("diagram", type=click.Path(path_type=Path, exists=True, dir_okay=False))
def validate_command(diagram: Path) -> None:
    """Validate one uncompressed draw.io DIAGRAM."""
    try:
        errors, skipped = validate_source(diagram.read_bytes())
    except (OSError, DiagramValidationError) as exc:
        raise click.ClickException(str(exc)) from exc
    for page_name in skipped:
        logger.warning("compressed_page_skipped", diagram=str(diagram), page=page_name)
    if errors:
        formatted = "\n".join(f"- {error}" for error in errors)
        raise click.ClickException(f"{len(errors)} validation error(s):\n{formatted}")
    click.echo(f"Valid draw.io diagram: {diagram}")


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="drawio-validator-coverage-") as directory:
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


def valid_diagram() -> bytes:
    return b"""<mxfile><diagram name="Main"><mxGraphModel><root>
<mxCell id="0"/><mxCell id="1" parent="0"/>
<mxCell id="title" parent="1" vertex="1" style="text;html=1;fontSize=18">
<mxGeometry /></mxCell><mxCell id="node" parent="1" vertex="1"><mxGeometry /></mxCell>
<mxCell id="edge" parent="1" edge="1" source="title" target="node"><mxGeometry /></mxCell>
</root></mxGraphModel></diagram></mxfile>"""


def test_validate_source_accepts_valid_and_floating_edges() -> None:
    errors, skipped = validate_source(valid_diagram())
    assert errors == []
    assert skipped == []
    assert endpoint_exists(
        ET.fromstring(
            b'<mxCell><mxGeometry><mxPoint as="sourcePoint"/></mxGeometry></mxCell>'
        ),
        "source",
        set(),
    )


@pytest.mark.parametrize(
    ("source", "message"),
    [
        (b"<bad>", "invalid draw.io XML"),
        (b"<other/>", "root element"),
        (b"<mxfile/>", "no <diagram>"),
    ],
)
def test_validate_source_rejects_invalid_documents(source: bytes, message: str) -> None:
    with pytest.raises(DiagramValidationError, match=message):
        validate_source(source)


def test_validate_source_reports_page_and_cell_errors() -> None:
    source = b"""<mxfile><diagram><mxGraphModel /></diagram>
<diagram name="Bad"><mxGraphModel><root>
<mxCell id="x" parent="missing"/><mxCell id="x" vertex="1"/>
<mxCell edge="1" parent="x" source="missing"/>
</root></mxGraphModel></diagram><diagram name="Packed">compressed</diagram></mxfile>"""
    errors, skipped = validate_source(source)
    report = "\n".join(errors)
    assert "Missing <root>" in report
    assert "Duplicate" in report
    assert "Missing required root" in report
    assert "Missing required default-layer" in report
    assert "Cell 1 must have id='0'" in report
    assert "Cell 2 must have id='1'" in report
    assert "No title" in report
    assert "invalid parent" in report
    assert "missing <mxGeometry>" in report
    assert "invalid source" in report
    assert "invalid target" in report
    assert skipped == ["Packed"]


def test_validate_cells_checks_layer_and_title_style_variant() -> None:
    root = ET.fromstring(b"""<root><mxCell id="0"/><mxCell id="1" parent="bad"/>
<mxCell id="title" parent="1" vertex="1" style="rounded=0;text;fontSize=18"><mxGeometry/></mxCell>
    </root>""")
    errors = validate_cells(root.findall("mxCell"), "Variant")
    assert errors == [
        "[diagram 'Variant'] Cell id='1' must have parent='0'",
        "[diagram 'Variant'] Cell id='1' has an invalid parent",
    ]


def test_validate_command_reports_success_and_skipped_page(tmp_path: Path) -> None:
    target = tmp_path / "diagram.drawio"
    target.write_bytes(
        valid_diagram().replace(b"</mxfile>", b'<diagram name="Packed"/></mxfile>')
    )
    result = CliRunner().invoke(cli, ["validate", str(target)])
    assert result.exit_code == 0
    assert "Valid draw.io diagram" in result.stdout
    assert "compressed_page_skipped" in result.stderr


def test_validate_command_reports_errors(tmp_path: Path) -> None:
    target = tmp_path / "diagram.drawio"
    target.write_bytes(b"<other/>")
    result = CliRunner().invoke(cli, ["validate", str(target)])
    assert result.exit_code == 1
    assert "root element" in result.stderr

    target.write_bytes(
        b"<mxfile><diagram><mxGraphModel><root /></mxGraphModel></diagram></mxfile>"
    )
    result = CliRunner().invoke(cli, ["validate", str(target)])
    assert result.exit_code == 1
    assert "validation error(s)" in result.stderr


def test_compact_pytest_output_filters_banners() -> None:
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
    assert "validate" in result.stdout
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
    assert "Inspect draw.io" in process.stdout


if __name__ == "__main__":
    cli()
