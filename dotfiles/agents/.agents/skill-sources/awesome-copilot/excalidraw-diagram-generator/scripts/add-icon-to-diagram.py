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

"""Add a transformed library icon to an Excalidraw diagram."""

from __future__ import annotations

import contextlib
import copy
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
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    JsonValue,
    TypeAdapter,
    ValidationError,
)

logger = log.get_logger(__name__)
Element = dict[str, JsonValue]
ELEMENTS_ADAPTER = TypeAdapter(list[Element])


class IconError(Exception):
    """Report an expected icon, diagram, or filesystem failure."""


class Diagram(BaseModel):
    """Validate the mutable portion while preserving Excalidraw metadata."""

    model_config = ConfigDict(extra="allow")
    elements: list[Element] = Field(default_factory=list)


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


def number(element: Element, key: str, default: float = 0) -> float:
    """Read one finite JSON number and reject booleans or other values."""
    value = element.get(key, default)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise IconError(f"element field {key!r} must be numeric")
    return float(value)


def calculate_bounding_box(
    elements: list[Element],
) -> tuple[float, float, float, float]:
    """Return the bounding box of positioned icon elements."""
    positioned = [element for element in elements if "x" in element and "y" in element]
    if not positioned:
        return 0, 0, 0, 0
    min_x = min(number(element, "x") for element in positioned)
    min_y = min(number(element, "y") for element in positioned)
    max_x = max(
        number(element, "x") + number(element, "width") for element in positioned
    )
    max_y = max(
        number(element, "y") + number(element, "height") for element in positioned
    )
    return min_x, min_y, max_x, max_y


def string_list(element: Element, key: str) -> list[str]:
    """Validate a JSON string-list field."""
    value = element.get(key, [])
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise IconError(f"element field {key!r} must be a string list")
    return value


def remap_binding(element: Element, key: str, identifiers: dict[str, str]) -> None:
    """Update one optional binding object in place."""
    binding = element.get(key)
    if binding is None:
        return
    if not isinstance(binding, dict):
        raise IconError(f"element field {key!r} must be an object")
    old_identifier = binding.get("elementId")
    if isinstance(old_identifier, str) and old_identifier in identifiers:
        binding["elementId"] = identifiers[old_identifier]


def transform_icon_elements(
    elements: list[Element], target_x: float, target_y: float
) -> list[Element]:
    """Translate icon elements and consistently replace internal identifiers."""
    if not elements:
        return []
    min_x, min_y, _, _ = calculate_bounding_box(elements)
    offset_x = target_x - min_x
    offset_y = target_y - min_y
    identifiers = {
        identifier: generate_unique_id()
        for element in elements
        if isinstance(identifier := element.get("id"), str)
    }
    group_identifiers = {
        group_id: generate_unique_id()
        for element in elements
        for group_id in string_list(element, "groupIds")
    }
    transformed: list[Element] = []
    for element in elements:
        updated = copy.deepcopy(element)
        if "x" in updated:
            updated["x"] = number(updated, "x") + offset_x
        if "y" in updated:
            updated["y"] = number(updated, "y") + offset_y
        identifier = updated.get("id")
        if isinstance(identifier, str):
            updated["id"] = identifiers[identifier]
        if "groupIds" in updated:
            updated["groupIds"] = [
                group_identifiers[group_id]
                for group_id in string_list(updated, "groupIds")
            ]
        remap_binding(updated, "startBinding", identifiers)
        remap_binding(updated, "endBinding", identifiers)
        container_id = updated.get("containerId")
        if isinstance(container_id, str) and container_id in identifiers:
            updated["containerId"] = identifiers[container_id]
        bound_elements = updated.get("boundElements")
        if bound_elements is not None:
            if not isinstance(bound_elements, list):
                raise IconError("element field 'boundElements' must be a list")
            for bound_element in bound_elements:
                if isinstance(bound_element, dict):
                    bound_id = bound_element.get("id")
                    if isinstance(bound_id, str) and bound_id in identifiers:
                        bound_element["id"] = identifiers[bound_id]
        transformed.append(updated)
    return transformed


def create_text_label(text: str, x: float, y: float) -> Element:
    """Build a simple centered Excalidraw text label."""
    seed = 1_000_000_000 + hash(text) % 1_000_000_000
    return {
        "id": generate_unique_id(),
        "type": "text",
        "x": x,
        "y": y,
        "width": len(text) * 10,
        "height": 20,
        "angle": 0,
        "strokeColor": "#1e1e1e",
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
        "seed": seed,
        "version": 1,
        "versionNonce": seed + 1_000_000_000,
        "isDeleted": False,
        "boundElements": [],
        "updated": 1_738_195_200_000,
        "link": None,
        "locked": False,
        "text": text,
        "fontSize": 16,
        "fontFamily": 5,
        "textAlign": "center",
        "verticalAlign": "top",
        "containerId": None,
        "originalText": text,
        "autoResize": True,
        "lineHeight": 1.25,
    }


def load_icon(icon_name: str, library_path: Path) -> list[Element]:
    """Load ICON_NAME without permitting traversal outside the icon directory."""
    if Path(icon_name).name != icon_name or icon_name in {"", ".", ".."}:
        raise IconError("icon name must be a plain filename stem")
    icon_path = library_path / "icons" / f"{icon_name}.json"
    try:
        document = json.loads(icon_path.read_bytes())
        if not isinstance(document, dict):
            raise IconError("icon document must be a JSON object")
        return ELEMENTS_ADAPTER.validate_python(document.get("elements", []))
    except OSError as exc:
        raise IconError(f"could not read icon {icon_path}: {exc}") from exc
    except (json.JSONDecodeError, ValidationError) as exc:
        raise IconError(f"invalid icon {icon_path}: {exc}") from exc


def add_icon_to_source(
    diagram_source: bytes,
    icon_elements: list[Element],
    *,
    x: float,
    y: float,
    label: str | None,
) -> tuple[bytes, int]:
    """Return a validated diagram containing a transformed icon."""
    try:
        diagram = Diagram.model_validate(json.loads(diagram_source))
    except (json.JSONDecodeError, ValidationError) as exc:
        raise IconError(f"invalid Excalidraw diagram: {exc}") from exc
    transformed = transform_icon_elements(icon_elements, x, y)
    if label and transformed:
        min_x, _, max_x, max_y = calculate_bounding_box(transformed)
        transformed.append(
            create_text_label(
                label, min_x + (max_x - min_x) / 2 - len(label) * 5, max_y + 10
            )
        )
    diagram.elements.extend(transformed)
    payload = json.dumps(
        diagram.model_dump(mode="json"),
        option=json.OPT_INDENT_2 | json.OPT_APPEND_NEWLINE,
    )
    return payload, len(transformed)


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
    """Write via an editor-safe suffix and restore the canonical path on failure."""
    if not use_edit_suffix or path.suffix != ".excalidraw":
        write_atomic(path, payload)
        return
    edit_path = path.with_suffix(".excalidraw.edit")
    if edit_path.exists():
        raise IconError(f"edit file already exists: {edit_path}")
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
    """Modify Excalidraw diagrams using reusable icon libraries."""
    configure_logging()


@cli.command(name="add")
@click.argument("diagram", type=click.Path(path_type=Path, exists=True, dir_okay=False))
@click.argument("icon_name")
@click.argument("x", type=float)
@click.argument("y", type=float)
@click.option(
    "--library-path",
    type=click.Path(path_type=Path, exists=True, file_okay=False),
    default=Path(__file__).parent.parent / "libraries" / "aws-architecture-icons",
    show_default=True,
)
@click.option("--label")
@click.option("--edit-suffix/--no-edit-suffix", default=True, show_default=True)
@click.option("--dry-run", is_flag=True, help="Validate and describe without writing.")
@click.option("--yes", is_flag=True, help="Write without interactive confirmation.")
def add_command(
    diagram: Path,
    icon_name: str,
    x: float,
    y: float,
    library_path: Path,
    label: str | None,
    edit_suffix: bool,
    dry_run: bool,
    yes: bool,
) -> None:
    """Add ICON_NAME at X and Y in DIAGRAM."""
    try:
        icon_elements = load_icon(icon_name, library_path)
        payload, added_count = add_icon_to_source(
            diagram.read_bytes(), icon_elements, x=x, y=y, label=label
        )
    except (OSError, IconError) as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would add {added_count} element(s) from {icon_name}")
        return
    if not yes:
        click.confirm(f"Modify {diagram}?", abort=True)
    try:
        commit_edit(diagram, payload, use_edit_suffix=edit_suffix)
    except (OSError, IconError) as exc:
        raise click.ClickException(f"could not update {diagram}: {exc}") from exc
    logger.info(
        "icon_added", diagram=str(diagram), icon=icon_name, element_count=added_count
    )
    click.echo(added_count)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="excalidraw-icon-coverage-") as directory:
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


def sample_elements() -> list[Element]:
    return [
        {
            "id": "box",
            "x": 10,
            "y": 20,
            "width": 30,
            "height": 40,
            "groupIds": ["group"],
            "boundElements": [{"id": "arrow", "type": "arrow"}],
        },
        {
            "id": "arrow",
            "x": 40,
            "y": 60,
            "width": 10,
            "height": 10,
            "groupIds": ["group"],
            "startBinding": {"elementId": "box"},
            "endBinding": {"elementId": "outside"},
            "containerId": "box",
        },
    ]


def test_bounding_box_and_number_validation() -> None:
    assert calculate_bounding_box([]) == (0, 0, 0, 0)
    assert calculate_bounding_box([{}]) == (0, 0, 0, 0)
    assert calculate_bounding_box(sample_elements()) == (10, 20, 50, 70)
    with pytest.raises(IconError, match="must be numeric"):
        number({"x": True}, "x")


def test_transform_icon_remaps_without_mutating_source(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    identifiers = iter(("new-box", "new-arrow", "new-group", "same-group"))
    monkeypatch.setattr(
        sys.modules[__name__], "generate_unique_id", lambda: next(identifiers)
    )
    source = sample_elements()
    transformed = transform_icon_elements(source, 100, 200)
    assert source[0]["id"] == "box"
    assert transformed[0]["x"] == 100
    assert transformed[0]["groupIds"] == ["same-group"]
    assert transformed[1]["startBinding"] == {"elementId": "new-box"}
    assert transformed[1]["endBinding"] == {"elementId": "outside"}
    assert transformed[1]["containerId"] == "new-box"
    assert transformed[0]["boundElements"] == [{"id": "new-arrow", "type": "arrow"}]
    assert transform_icon_elements([], 1, 2) == []
    monkeypatch.setattr(sys.modules[__name__], "generate_unique_id", lambda: "fresh")
    external = transform_icon_elements(
        [{"id": "only", "boundElements": [None, {"id": "external"}, {}]}], 0, 0
    )
    assert external[0]["boundElements"] == [None, {"id": "external"}, {}]


@pytest.mark.parametrize(
    ("elements", "message"),
    [
        ([{"groupIds": "bad"}], "string list"),
        ([{"startBinding": "bad"}], "must be an object"),
        ([{"boundElements": "bad"}], "must be a list"),
    ],
)
def test_transform_icon_rejects_invalid_nested_fields(
    elements: list[Element], message: str
) -> None:
    with pytest.raises(IconError, match=message):
        transform_icon_elements(elements, 0, 0)


def test_create_text_label() -> None:
    label = create_text_label("API", 10, 20)
    assert label["text"] == "API"
    assert label["width"] == 30


def test_load_icon_validates_name_and_document(tmp_path: Path) -> None:
    icons = tmp_path / "icons"
    icons.mkdir()
    (icons / "Good.json").write_bytes(b'{"elements":[]}')
    assert load_icon("Good", tmp_path) == []
    with pytest.raises(IconError, match="plain filename"):
        load_icon("../bad", tmp_path)
    (icons / "Bad.json").write_bytes(b"[")
    with pytest.raises(IconError, match="invalid icon"):
        load_icon("Bad", tmp_path)
    (icons / "Object.json").write_bytes(b"[]")
    with pytest.raises(IconError, match="JSON object"):
        load_icon("Object", tmp_path)
    with pytest.raises(IconError, match="could not read"):
        load_icon("Missing", tmp_path)


def test_add_icon_to_source_adds_label_and_preserves_metadata() -> None:
    payload, count = add_icon_to_source(
        b'{"type":"excalidraw","elements":[]}', sample_elements(), x=0, y=0, label="API"
    )
    document = json.loads(payload)
    assert count == 3
    assert document["type"] == "excalidraw"
    assert payload.endswith(b"\n")
    payload, count = add_icon_to_source(b"{}", [], x=0, y=0, label="unused")
    assert count == 0
    with pytest.raises(IconError, match="invalid Excalidraw"):
        add_icon_to_source(b"{", [], x=0, y=0, label=None)


def test_commit_edit_modes_collisions_and_recovery(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    direct = tmp_path / "diagram.json"
    direct.write_bytes(b"old")
    commit_edit(direct, b"new", use_edit_suffix=True)
    assert direct.read_bytes() == b"new"
    diagram = tmp_path / "diagram.excalidraw"
    diagram.write_bytes(b"old")
    commit_edit(diagram, b"new", use_edit_suffix=True)
    assert diagram.read_bytes() == b"new"
    diagram.with_suffix(".excalidraw.edit").write_bytes(b"busy")
    with pytest.raises(IconError, match="already exists"):
        commit_edit(diagram, b"newer", use_edit_suffix=True)
    diagram.with_suffix(".excalidraw.edit").unlink()

    def fail(_path: Path, _payload: bytes) -> None:
        raise OSError("disk full")

    monkeypatch.setattr(sys.modules[__name__], "write_atomic", fail)
    with pytest.raises(OSError, match="disk full"):
        commit_edit(diagram, b"newer", use_edit_suffix=True)
    assert diagram.read_bytes() == b"new"

    def restore_then_fail(edit_path: Path, _payload: bytes) -> None:
        os.replace(edit_path, diagram)
        raise OSError("late failure")

    monkeypatch.setattr(sys.modules[__name__], "write_atomic", restore_then_fail)
    with pytest.raises(OSError, match="late failure"):
        commit_edit(diagram, b"newer", use_edit_suffix=True)


def make_library(tmp_path: Path) -> Path:
    library = tmp_path / "library"
    icons = library / "icons"
    icons.mkdir(parents=True)
    (icons / "Box.json").write_bytes(json.dumps({"elements": sample_elements()}))
    return library


def test_add_command_dry_run_and_write(tmp_path: Path) -> None:
    library = make_library(tmp_path)
    diagram = tmp_path / "diagram.excalidraw"
    diagram.write_bytes(b'{"elements":[]}')
    runner = CliRunner()
    dry_run = runner.invoke(
        cli,
        [
            "add",
            str(diagram),
            "Box",
            "1",
            "2",
            "--library-path",
            str(library),
            "--dry-run",
        ],
    )
    assert dry_run.exit_code == 0
    assert "Would add 2" in dry_run.stdout
    written = runner.invoke(
        cli,
        [
            "add",
            str(diagram),
            "Box",
            "1",
            "2",
            "--library-path",
            str(library),
            "--label",
            "Service",
        ],
        input="y\n",
    )
    assert written.exit_code == 0
    assert len(json.loads(diagram.read_bytes())["elements"]) == 3


def test_add_command_translates_errors(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    library = make_library(tmp_path)
    diagram = tmp_path / "diagram.excalidraw"
    diagram.write_bytes(b"{")
    arguments = [
        "add",
        str(diagram),
        "Box",
        "1",
        "2",
        "--library-path",
        str(library),
        "--dry-run",
    ]
    result = CliRunner().invoke(cli, arguments)
    assert result.exit_code == 1
    assert "invalid Excalidraw" in result.stderr
    diagram.write_bytes(b'{"elements":[]}')

    def fail(_path: Path, _payload: bytes, *, use_edit_suffix: bool) -> None:
        raise OSError(f"write failed: {use_edit_suffix}")

    monkeypatch.setattr(sys.modules[__name__], "commit_edit", fail)
    arguments[-1] = "--yes"
    result = CliRunner().invoke(cli, arguments)
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
