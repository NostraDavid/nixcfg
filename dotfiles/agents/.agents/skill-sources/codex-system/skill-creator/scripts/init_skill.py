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

"""Create a complete Codex skill directory from a conservative template."""

from __future__ import annotations

import contextlib
import io
import os
import shutil
import subprocess as sp
import sys
import tempfile
from pathlib import Path

import click
import pytest
import regex as re
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from generate_openai_yaml import MetadataError, write_openai_yaml

MAX_SKILL_NAME_LENGTH = 64
ALLOWED_RESOURCES = {"scripts", "references", "assets"}
logger = log.get_logger(__name__)


class SkillInitError(Exception):
    """Report an expected skill initialization failure."""


SKILL_TEMPLATE = """---
name: {skill_name}
description: [TODO: Complete and informative explanation of what the skill does and when to use it. Include WHEN to use this skill - specific scenarios, file types, or tasks that trigger it.]
---

# {skill_title}

## Overview

[TODO: 1-2 sentences explaining what this skill enables]

## Structuring This Skill

[TODO: Choose the structure that best fits this skill's purpose. Common patterns:

**1. Workflow-Based** (best for sequential processes)
- Works well when there are clear step-by-step procedures
- Example: DOCX skill with "Workflow Decision Tree" -> "Reading" -> "Creating" -> "Editing"
- Structure: ## Overview -> ## Workflow Decision Tree -> ## Step 1 -> ## Step 2...

**2. Task-Based** (best for tool collections)
- Works well when the skill offers different operations/capabilities
- Example: PDF skill with "Quick Start" -> "Merge PDFs" -> "Split PDFs" -> "Extract Text"
- Structure: ## Overview -> ## Quick Start -> ## Task Category 1 -> ## Task Category 2...

**3. Reference/Guidelines** (best for standards or specifications)
- Works well for brand guidelines, coding standards, or requirements
- Example: Brand styling with "Brand Guidelines" -> "Colors" -> "Typography" -> "Features"
- Structure: ## Overview -> ## Guidelines -> ## Specifications -> ## Usage...

**4. Capabilities-Based** (best for integrated systems)
- Works well when the skill provides multiple interrelated features
- Example: Product Management with "Core Capabilities" -> numbered capability list
- Structure: ## Overview -> ## Core Capabilities -> ### 1. Feature -> ### 2. Feature...

Patterns can be mixed and matched as needed. Most skills combine patterns (e.g., start with task-based, add workflow for complex operations).

Delete this entire "Structuring This Skill" section when done - it's just guidance.]

## [TODO: Replace with the first main section based on chosen structure]

[TODO: Add content here. See examples in existing skills:
- Code samples for technical skills
- Decision trees for complex workflows
- Concrete examples with realistic user requests
- References to scripts/templates/references as needed]

## Resources (optional)

Create only the resource directories this skill actually needs. Delete this section if no resources are required.

### scripts/
Executable code (Python/Bash/etc.) that can be run directly to perform specific operations.

**Examples from other skills:**
- PDF skill: `fill_fillable_fields.py`, `extract_form_field_info.py` - utilities for PDF manipulation
- DOCX skill: `document.py`, `utilities.py` - Python modules for document processing

**Appropriate for:** Python scripts, shell scripts, or any executable code that performs automation, data processing, or specific operations.

**Note:** Scripts may be executed without loading into context, but can still be read by Codex for patching or environment adjustments.

### references/
Documentation and reference material intended to be loaded into context to inform Codex's process and thinking.

**Examples from other skills:**
- Product management: `communication.md`, `context_building.md` - detailed workflow guides
- BigQuery: API reference documentation and query examples
- Finance: Schema documentation, company policies

**Appropriate for:** In-depth documentation, API references, database schemas, comprehensive guides, or any detailed information that Codex should reference while working.

### assets/
Files not intended to be loaded into context, but rather used within the output Codex produces.

**Examples from other skills:**
- Brand styling: PowerPoint template files (.pptx), logo files
- Frontend builder: HTML/React boilerplate project directories
- Typography: Font files (.ttf, .woff2)

**Appropriate for:** Templates, boilerplate code, document templates, images, icons, fonts, or any files meant to be copied or used in the final output.

---

**Not every skill requires all three types of resources.**
"""

EXAMPLE_REFERENCE = """# Reference Documentation for {skill_title}

This is a placeholder for detailed reference documentation.
Replace with actual reference content or delete if not needed.

Example real reference docs from other skills:
- product-management/references/communication.md - Comprehensive guide for status updates
- product-management/references/context_building.md - Deep-dive on gathering context
- bigquery/references/ - API references and query examples

## When Reference Docs Are Useful

Reference docs are ideal for:
- Comprehensive API documentation
- Detailed workflow guides
- Complex multi-step processes
- Information too lengthy for main SKILL.md
- Content that's only needed for specific use cases

## Structure Suggestions

### API Reference Example
- Overview
- Authentication
- Endpoints with examples
- Error codes
- Rate limits

### Workflow Guide Example
- Prerequisites
- Step-by-step instructions
- Common patterns
- Troubleshooting
- Best practices
"""

EXAMPLE_ASSET = """# Example Asset File

This placeholder represents where asset files would be stored.
Replace with actual asset files (templates, images, fonts, etc.) or delete if not needed.

Asset files are NOT intended to be loaded into context, but rather used within
the output Codex produces.

Example asset files from other skills:
- Brand guidelines: logo.png, slides_template.pptx
- Frontend builder: hello-world/ directory with HTML/React boilerplate
- Typography: custom-font.ttf, font-family.woff2
- Data: sample_data.csv, test_dataset.json

## Common Asset Types

- Templates: .pptx, .docx, boilerplate directories
- Images: .png, .jpg, .svg, .gif
- Fonts: .ttf, .otf, .woff, .woff2
- Boilerplate code: Project directories, starter files
- Icons: .ico, .svg
- Data files: .csv, .json, .xml, .yaml

Note: This is a text placeholder. Actual assets can be any file type.
"""


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


def normalize_skill_name(skill_name: str) -> str:
    """Normalize a skill name to lowercase hyphen-case."""
    normalized = re.sub(r"[^a-z0-9]+", "-", skill_name.strip().lower())
    return re.sub(r"-{2,}", "-", normalized).strip("-")


def validate_skill_name(skill_name: str) -> None:
    """Enforce the portable skill-name length and content contract."""
    if not skill_name:
        raise SkillInitError("skill name must contain at least one letter or digit")
    if len(skill_name) > MAX_SKILL_NAME_LENGTH:
        raise SkillInitError(
            f"skill name is {len(skill_name)} characters; maximum is {MAX_SKILL_NAME_LENGTH}"
        )


def title_case_skill_name(skill_name: str) -> str:
    """Convert a hyphenated skill name to a display title."""
    return " ".join(word.capitalize() for word in skill_name.split("-"))


def parse_resources(raw_resources: str) -> tuple[str, ...]:
    """Parse, validate, and de-duplicate a comma-separated resource list."""
    resources = tuple(
        dict.fromkeys(item.strip() for item in raw_resources.split(",") if item.strip())
    )
    invalid = sorted(set(resources) - ALLOWED_RESOURCES)
    if invalid:
        raise SkillInitError(
            f"unknown resource type(s): {', '.join(invalid)}; allowed: "
            f"{', '.join(sorted(ALLOWED_RESOURCES))}"
        )
    return resources


def create_resource_dirs(
    skill_dir: Path,
    skill_name: str,
    skill_title: str,
    resources: tuple[str, ...],
    *,
    include_examples: bool,
) -> None:
    """Create requested resource directories and optional text examples."""
    examples = {
        "scripts": (
            "README.md",
            "# Scripts\n\nUse `$python-native-script-builder` for standard-library-only helpers or `$python-uv-script-builder` when dependencies are needed.\n",
        ),
        "references": (
            "api_reference.md",
            EXAMPLE_REFERENCE.format(skill_title=skill_title),
        ),
        "assets": ("example_asset.txt", EXAMPLE_ASSET),
    }
    for resource in resources:
        resource_dir = skill_dir / resource
        resource_dir.mkdir()
        if include_examples:
            filename, content = examples[resource]
            resource_dir.joinpath(filename).write_text(content, encoding="utf-8")


def initialize_skill(
    skill_name: str,
    output_parent: Path,
    resources: tuple[str, ...],
    *,
    include_examples: bool,
    interface_overrides: tuple[str, ...],
) -> Path:
    """Build a complete skill in staging and atomically publish the directory."""
    skill_dir = output_parent.resolve() / skill_name
    if skill_dir.exists():
        raise SkillInitError(f"skill directory already exists: {skill_dir}")
    output_parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=f".{skill_name}.", dir=output_parent))
    try:
        skill_title = title_case_skill_name(skill_name)
        stage.joinpath("SKILL.md").write_text(
            SKILL_TEMPLATE.format(skill_name=skill_name, skill_title=skill_title),
            encoding="utf-8",
        )
        write_openai_yaml(stage, skill_name, interface_overrides)
        create_resource_dirs(
            stage,
            skill_name,
            skill_title,
            resources,
            include_examples=include_examples,
        )
        os.replace(stage, skill_dir)
    except (OSError, MetadataError, KeyError) as exc:
        shutil.rmtree(stage, ignore_errors=True)
        raise SkillInitError(f"could not initialize skill: {exc}") from exc
    return skill_dir


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
    """Create Codex skill directories."""
    configure_logging()


@cli.command(name="create")
@click.argument("skill_name")
@click.option("--path", "output_parent", type=click.Path(path_type=Path), required=True)
@click.option(
    "--resources", default="", help="Comma-separated scripts,references,assets."
)
@click.option(
    "--examples", is_flag=True, help="Add text examples to selected resources."
)
@click.option(
    "--interface", "interfaces", multiple=True, help="Repeatable key=value UI override."
)
@click.option(
    "--dry-run", is_flag=True, help="Validate and describe without creating files."
)
@click.option("--yes", is_flag=True, help="Create without interactive confirmation.")
def create_command(
    skill_name: str,
    output_parent: Path,
    resources: str,
    examples: bool,
    interfaces: tuple[str, ...],
    dry_run: bool,
    yes: bool,
) -> None:
    """Create SKILL_NAME beneath --path."""
    normalized_name = normalize_skill_name(skill_name)
    try:
        validate_skill_name(normalized_name)
        parsed_resources = parse_resources(resources)
        if examples and not parsed_resources:
            raise SkillInitError("--examples requires --resources")
        target = output_parent.resolve() / normalized_name
        if target.exists():
            raise SkillInitError(f"skill directory already exists: {target}")
    except SkillInitError as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would create {target}")
        return
    if not yes:
        click.confirm(f"Create {target}?", abort=True)
    try:
        result = initialize_skill(
            normalized_name,
            output_parent,
            parsed_resources,
            include_examples=examples,
            interface_overrides=interfaces,
        )
    except SkillInitError as exc:
        raise click.ClickException(str(exc)) from exc
    logger.info("skill_initialized", skill=normalized_name, output=str(result))
    click.echo(result)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="skill-init-coverage-") as directory:
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


def test_name_helpers() -> None:
    assert normalize_skill_name(" My API__Skill ") == "my-api-skill"
    assert title_case_skill_name("my-api-skill") == "My Api Skill"
    validate_skill_name("valid")
    with pytest.raises(SkillInitError, match="at least one"):
        validate_skill_name("")
    with pytest.raises(SkillInitError, match="maximum is 64"):
        validate_skill_name("a" * 65)


def test_parse_resources_deduplicates_and_rejects_unknown() -> None:
    assert parse_resources("") == ()
    assert parse_resources("scripts, references, scripts") == ("scripts", "references")
    with pytest.raises(SkillInitError, match="unknown resource"):
        parse_resources("scripts,unknown")


def test_initialize_skill_creates_complete_tree(tmp_path: Path) -> None:
    result = initialize_skill(
        "sample-skill",
        tmp_path,
        ("scripts", "references", "assets"),
        include_examples=True,
        interface_overrides=("short_description=Create useful sample skill workflows",),
    )
    assert result == tmp_path / "sample-skill"
    assert (result / "SKILL.md").exists()
    assert (result / "agents" / "openai.yaml").exists()
    assert (result / "scripts" / "README.md").exists()
    assert (result / "references" / "api_reference.md").exists()
    assert (result / "assets" / "example_asset.txt").exists()
    assert not list(tmp_path.glob(".sample-skill.*"))
    with pytest.raises(SkillInitError, match="already exists"):
        initialize_skill(
            "sample-skill", tmp_path, (), include_examples=False, interface_overrides=()
        )


def test_initialize_skill_cleans_staging_on_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fail(*_args: object, **_kwargs: object) -> Path:
        raise MetadataError("bad metadata")

    monkeypatch.setattr(sys.modules[__name__], "write_openai_yaml", fail)
    with pytest.raises(SkillInitError, match="bad metadata"):
        initialize_skill(
            "broken", tmp_path, (), include_examples=False, interface_overrides=()
        )
    assert list(tmp_path.iterdir()) == []


def test_create_command_dry_run_write_and_errors(tmp_path: Path) -> None:
    runner = CliRunner()
    dry_run = runner.invoke(
        cli, ["create", "My Skill", "--path", str(tmp_path), "--dry-run"]
    )
    assert dry_run.exit_code == 0
    assert "my-skill" in dry_run.stdout
    written = runner.invoke(
        cli,
        [
            "create",
            "My Skill",
            "--path",
            str(tmp_path),
            "--resources",
            "scripts",
        ],
        input="y\n",
    )
    assert written.exit_code == 0
    assert (tmp_path / "my-skill" / "scripts").is_dir()
    duplicate = runner.invoke(
        cli, ["create", "My Skill", "--path", str(tmp_path), "--yes"]
    )
    assert duplicate.exit_code == 1
    assert "already exists" in duplicate.stderr
    missing_resources = runner.invoke(
        cli, ["create", "other", "--path", str(tmp_path), "--examples", "--dry-run"]
    )
    assert missing_resources.exit_code == 1
    assert "requires --resources" in missing_resources.stderr


def test_create_command_translates_initialization_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fail(*_args: object, **_kwargs: object) -> Path:
        raise SkillInitError("creation failed")

    monkeypatch.setattr(sys.modules[__name__], "initialize_skill", fail)
    result = CliRunner().invoke(
        cli, ["create", "sample", "--path", str(tmp_path), "--yes"]
    )
    assert result.exit_code == 1
    assert "creation failed" in result.stderr


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
    assert "create" in result.stdout
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
    assert "Create Codex" in process.stdout


if __name__ == "__main__":
    cli()
