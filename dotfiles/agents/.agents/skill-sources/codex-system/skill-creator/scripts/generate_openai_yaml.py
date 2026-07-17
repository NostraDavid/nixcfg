#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "pydantic==2.12.5",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "pyyaml==6.0.3",
#     "regex==2026.2.28",
#     "structlog==26.1.0",
# ]
# ///

"""Generate agents/openai.yaml metadata for a Codex skill."""

from __future__ import annotations

import contextlib
import io
import os
import subprocess as sp
import sys
import tempfile
from pathlib import Path

import click
import pytest
import regex as re
import structlog as sl
import structlog.stdlib as log
import yaml
from click.testing import CliRunner
from pydantic import BaseModel, ValidationError

ACRONYMS = frozenset(
    {"GH", "MCP", "API", "CI", "CLI", "LLM", "PDF", "PR", "UI", "URL", "SQL"}
)
BRANDS = {
    "openai": "OpenAI",
    "openapi": "OpenAPI",
    "github": "GitHub",
    "pagerduty": "PagerDuty",
    "datadog": "Datadog",
    "sqlite": "SQLite",
    "fastapi": "FastAPI",
}
SMALL_WORDS = frozenset({"and", "or", "to", "up", "with"})
REQUIRED_INTERFACE_KEYS = ("display_name", "short_description")
OPTIONAL_INTERFACE_KEYS = (
    "icon_small",
    "icon_large",
    "brand_color",
    "default_prompt",
)
ALLOWED_INTERFACE_KEYS = frozenset(REQUIRED_INTERFACE_KEYS + OPTIONAL_INTERFACE_KEYS)
FRONTMATTER_PATTERN = re.compile(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", re.DOTALL)
logger = log.get_logger(__name__)


class MetadataError(Exception):
    """Report an expected skill metadata or output failure."""


class NameFrontmatter(BaseModel):
    """Validate the frontmatter field required by this generator."""

    name: str


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


def format_display_name(skill_name: str) -> str:
    """Convert a hyphenated skill name into a product-aware display name."""
    formatted: list[str] = []
    for index, word in enumerate(filter(None, skill_name.split("-"))):
        lower = word.lower()
        upper = word.upper()
        if upper in ACRONYMS:
            formatted.append(upper)
        elif lower in BRANDS:
            formatted.append(BRANDS[lower])
        elif index > 0 and lower in SMALL_WORDS:
            formatted.append(lower)
        else:
            formatted.append(word.capitalize())
    if not formatted:
        raise MetadataError("skill name must contain at least one word")
    return " ".join(formatted)


def generate_short_description(display_name: str) -> str:
    """Return a UI description within OpenAI's 25-64 character contract."""
    description = f"Help with {display_name} tasks and workflows"
    if len(description) > 64:
        description = f"{display_name} helper"
    if len(description) > 64:
        description = f"{display_name[:57].rstrip()} helper"
    return description


def read_frontmatter_name(skill_dir: Path) -> str:
    """Read the skill name from leading SKILL.md YAML frontmatter."""
    skill_md = skill_dir / "SKILL.md"
    try:
        content = skill_md.read_text(encoding="utf-8")
    except OSError as exc:
        raise MetadataError(f"could not read {skill_md}: {exc}") from exc
    match = FRONTMATTER_PATTERN.match(content)
    if match is None:
        raise MetadataError("SKILL.md must start with valid YAML frontmatter")
    try:
        document = yaml.safe_load(match.group(1))
        frontmatter = NameFrontmatter.model_validate(document)
    except yaml.YAMLError as exc:
        raise MetadataError(f"invalid YAML frontmatter: {exc}") from exc
    except ValidationError as exc:
        raise MetadataError(f"frontmatter name is missing or invalid: {exc}") from exc
    name = frontmatter.name.strip()
    if not name:
        raise MetadataError("frontmatter name must not be empty")
    return name


def parse_interface_overrides(raw_overrides: tuple[str, ...]) -> dict[str, str]:
    """Parse repeated key=value interface overrides."""
    overrides: dict[str, str] = {}
    for item in raw_overrides:
        if "=" not in item:
            raise MetadataError(f"invalid interface override {item!r}; use key=value")
        key, value = (part.strip() for part in item.split("=", 1))
        if not key:
            raise MetadataError(f"invalid interface override {item!r}; key is empty")
        if key not in ALLOWED_INTERFACE_KEYS:
            allowed = ", ".join(sorted(ALLOWED_INTERFACE_KEYS))
            raise MetadataError(f"unknown interface field {key!r}; allowed: {allowed}")
        overrides[key] = value
    return overrides


def render_openai_yaml(skill_name: str, raw_overrides: tuple[str, ...]) -> bytes:
    """Render deterministic OpenAI interface metadata."""
    overrides = parse_interface_overrides(raw_overrides)
    display_name = overrides.get("display_name") or format_display_name(skill_name)
    short_description = overrides.get(
        "short_description"
    ) or generate_short_description(display_name)
    if not 25 <= len(short_description) <= 64:
        raise MetadataError(
            f"short_description must be 25-64 characters, got {len(short_description)}"
        )
    interface = {
        "display_name": display_name,
        "short_description": short_description,
    }
    for key in OPTIONAL_INTERFACE_KEYS:
        if key in overrides:
            interface[key] = overrides[key]
    return yaml.safe_dump(
        {"interface": interface},
        allow_unicode=True,
        sort_keys=False,
    ).encode()


def write_atomic(path: Path, payload: bytes) -> None:
    """Create PATH atomically."""
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


def write_openai_yaml(
    skill_dir: Path,
    skill_name: str,
    raw_overrides: tuple[str, ...] | list[str],
    *,
    force: bool = False,
) -> Path:
    """Render and write agents/openai.yaml for callers such as init_skill.py."""
    output_path = skill_dir / "agents" / "openai.yaml"
    if output_path.exists() and not force:
        raise MetadataError(
            f"output already exists: {output_path}; pass --force to replace it"
        )
    write_atomic(output_path, render_openai_yaml(skill_name, tuple(raw_overrides)))
    return output_path


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
    """Generate Codex skill UI metadata."""
    configure_logging()


@cli.command(name="generate")
@click.argument(
    "skill_directory", type=click.Path(path_type=Path, exists=True, file_okay=False)
)
@click.option("--name", help="Override the SKILL.md frontmatter name.")
@click.option(
    "--interface", "interfaces", multiple=True, help="Repeatable key=value override."
)
@click.option("--force", is_flag=True, help="Replace an existing agents/openai.yaml.")
@click.option(
    "--dry-run", is_flag=True, help="Validate and print YAML without writing."
)
@click.option("--yes", is_flag=True, help="Write without interactive confirmation.")
def generate_command(
    skill_directory: Path,
    name: str | None,
    interfaces: tuple[str, ...],
    force: bool,
    dry_run: bool,
    yes: bool,
) -> None:
    """Generate agents/openai.yaml in SKILL_DIRECTORY."""
    try:
        skill_name = name or read_frontmatter_name(skill_directory)
        payload = render_openai_yaml(skill_name, interfaces)
    except MetadataError as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(payload.decode(), nl=False)
        return
    if not yes:
        click.confirm(f"Write agents/openai.yaml in {skill_directory}?", abort=True)
    try:
        output_path = write_openai_yaml(
            skill_directory, skill_name, interfaces, force=force
        )
    except (OSError, MetadataError) as exc:
        raise click.ClickException(str(exc)) from exc
    logger.info("openai_yaml_generated", skill=skill_name, output=str(output_path))
    click.echo(output_path)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="openai-yaml-coverage-") as directory:
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
        ("github-api-with-sql", "GitHub API with SQL"),
        ("fastapi-and-openai", "FastAPI and OpenAI"),
        ("plain-name", "Plain Name"),
    ],
)
def test_format_display_name(name: str, expected: str) -> None:
    assert format_display_name(name) == expected
    with pytest.raises(MetadataError, match="at least one word"):
        format_display_name("---")


def test_generate_short_description_handles_long_names() -> None:
    assert 25 <= len(generate_short_description("X")) <= 64
    assert generate_short_description("A" * 60).endswith("helper")
    assert len(generate_short_description("A" * 100)) <= 64


def test_read_frontmatter_name_success_and_errors(tmp_path: Path) -> None:
    skill_md = tmp_path / "SKILL.md"
    skill_md.write_text("---\nname: sample\n---\n", encoding="utf-8")
    assert read_frontmatter_name(tmp_path) == "sample"
    skill_md.write_text("bad", encoding="utf-8")
    with pytest.raises(MetadataError, match="valid YAML"):
        read_frontmatter_name(tmp_path)
    skill_md.write_text("---\n[bad\n---\n", encoding="utf-8")
    with pytest.raises(MetadataError, match="invalid YAML"):
        read_frontmatter_name(tmp_path)
    skill_md.write_text("---\ndescription: no name\n---\n", encoding="utf-8")
    with pytest.raises(MetadataError, match="missing or invalid"):
        read_frontmatter_name(tmp_path)
    skill_md.write_text("---\nname: '  '\n---\n", encoding="utf-8")
    with pytest.raises(MetadataError, match="must not be empty"):
        read_frontmatter_name(tmp_path)
    skill_md.unlink()
    with pytest.raises(MetadataError, match="could not read"):
        read_frontmatter_name(tmp_path)


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        (("bad",), "use key=value"),
        ((" =value",), "key is empty"),
        (("unknown=value",), "unknown interface field"),
    ],
)
def test_parse_interface_overrides_rejects_invalid_values(
    overrides: tuple[str, ...], message: str
) -> None:
    with pytest.raises(MetadataError, match=message):
        parse_interface_overrides(overrides)


def test_render_openai_yaml_uses_overrides_and_order() -> None:
    payload = render_openai_yaml(
        "sample",
        (
            "display_name=Custom",
            "short_description=Build custom skill metadata safely",
            "default_prompt=Use this skill.",
            "icon_small=./icon.svg",
            "display_name=Latest",
        ),
    )
    document = yaml.safe_load(payload)
    assert document["interface"]["display_name"] == "Latest"
    assert document["interface"]["default_prompt"] == "Use this skill."
    with pytest.raises(MetadataError, match="25-64"):
        render_openai_yaml("sample", ("short_description=short",))


def test_write_openai_yaml_requires_force(tmp_path: Path) -> None:
    output = write_openai_yaml(tmp_path, "sample", ())
    assert output.exists()
    with pytest.raises(MetadataError, match="--force"):
        write_openai_yaml(tmp_path, "sample", ())
    write_openai_yaml(tmp_path, "sample", (), force=True)


def test_generate_command_dry_run_write_and_errors(tmp_path: Path) -> None:
    (tmp_path / "SKILL.md").write_text("---\nname: sample\n---\n", encoding="utf-8")
    runner = CliRunner()
    dry_run = runner.invoke(cli, ["generate", str(tmp_path), "--dry-run"])
    assert dry_run.exit_code == 0
    assert "interface:" in dry_run.stdout
    written = runner.invoke(cli, ["generate", str(tmp_path)], input="y\n")
    assert written.exit_code == 0
    assert (tmp_path / "agents" / "openai.yaml").exists()
    duplicate = runner.invoke(cli, ["generate", str(tmp_path), "--yes"])
    assert duplicate.exit_code == 1
    assert "--force" in duplicate.stderr
    invalid = runner.invoke(
        cli,
        [
            "generate",
            str(tmp_path),
            "--name",
            "sample",
            "--interface",
            "bad",
            "--dry-run",
        ],
    )
    assert invalid.exit_code == 1
    assert "key=value" in invalid.stderr


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
    assert "generate" in result.stdout
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
    assert "Generate Codex" in process.stdout


if __name__ == "__main__":
    cli()
