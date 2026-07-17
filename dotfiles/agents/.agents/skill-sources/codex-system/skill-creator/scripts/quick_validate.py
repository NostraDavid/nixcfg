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

"""Validate the frontmatter contract of a Codex skill."""

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
from pydantic import BaseModel, ConfigDict, Field, ValidationError

MAX_SKILL_NAME_LENGTH = 64
MAX_DESCRIPTION_LENGTH = 1024
FRONTMATTER_PATTERN = re.compile(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", re.DOTALL)
logger = log.get_logger(__name__)


class SkillValidationError(Exception):
    """Report an expected skill validation failure."""


class SkillFrontmatter(BaseModel):
    """Describe the supported SKILL.md frontmatter fields."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)
    name: str
    description: str
    license: str | None = None
    allowed_tools: str | list[str] | None = Field(default=None, alias="allowed-tools")
    metadata: dict[str, object] | None = None


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


def parse_frontmatter(content: str) -> SkillFrontmatter:
    """Parse and schema-check the leading YAML frontmatter."""
    match = FRONTMATTER_PATTERN.match(content)
    if match is None:
        raise SkillValidationError("SKILL.md must start with valid YAML frontmatter")
    try:
        document = yaml.safe_load(match.group(1))
    except yaml.YAMLError as exc:
        raise SkillValidationError(f"invalid YAML frontmatter: {exc}") from exc
    if not isinstance(document, dict):
        raise SkillValidationError("frontmatter must be a YAML mapping")
    try:
        return SkillFrontmatter.model_validate(document)
    except ValidationError as exc:
        raise SkillValidationError(f"invalid frontmatter fields: {exc}") from exc


def validate_name(name: str) -> None:
    """Enforce the portable skill-name contract."""
    if not name:
        raise SkillValidationError("skill name must not be empty")
    if len(name) > MAX_SKILL_NAME_LENGTH:
        raise SkillValidationError(
            f"skill name is {len(name)} characters; maximum is {MAX_SKILL_NAME_LENGTH}"
        )
    if re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name) is None:
        raise SkillValidationError(
            "skill name must use lowercase hyphen-case without consecutive hyphens"
        )


def validate_description(description: str) -> None:
    """Reject descriptions that are empty, unsafe, or too long."""
    if not description.strip():
        raise SkillValidationError("skill description must not be empty")
    if len(description) > MAX_DESCRIPTION_LENGTH:
        raise SkillValidationError(
            f"skill description is {len(description)} characters; maximum is {MAX_DESCRIPTION_LENGTH}"
        )
    if "<" in description or ">" in description:
        raise SkillValidationError("skill description must not contain angle brackets")


def validate_skill(skill_path: Path) -> SkillFrontmatter:
    """Validate SKILL.md in SKILL_PATH and return its frontmatter."""
    skill_md = skill_path / "SKILL.md"
    try:
        content = skill_md.read_text(encoding="utf-8")
    except OSError as exc:
        raise SkillValidationError(f"could not read {skill_md}: {exc}") from exc
    frontmatter = parse_frontmatter(content)
    validate_name(frontmatter.name.strip())
    validate_description(frontmatter.description)
    return frontmatter


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
    """Validate Codex skill metadata."""
    configure_logging()


@cli.command(name="validate")
@click.argument(
    "skill_directory", type=click.Path(path_type=Path, exists=True, file_okay=False)
)
def validate_command(skill_directory: Path) -> None:
    """Validate SKILL.md in SKILL_DIRECTORY."""
    try:
        frontmatter = validate_skill(skill_directory)
    except SkillValidationError as exc:
        raise click.ClickException(str(exc)) from exc
    logger.info("skill_validated", skill=str(skill_directory), name=frontmatter.name)
    click.echo("Skill is valid.")


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="skill-validator-coverage-") as directory:
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


def skill_document(
    name: str = "valid-skill", description: str = "Useful skill."
) -> str:
    return f"---\nname: {name}\ndescription: {description}\n---\n\n# Skill\n"


def test_validate_skill_accepts_supported_frontmatter(tmp_path: Path) -> None:
    (tmp_path / "SKILL.md").write_text(
        "---\nname: valid-skill\ndescription: Useful skill.\nlicense: MIT\n"
        "allowed-tools: [Read]\nmetadata: {owner: me}\n---\n",
        encoding="utf-8",
    )
    frontmatter = validate_skill(tmp_path)
    assert frontmatter.name == "valid-skill"
    assert frontmatter.allowed_tools == ["Read"]


def test_validate_skill_reports_missing_file(tmp_path: Path) -> None:
    with pytest.raises(SkillValidationError, match="could not read"):
        validate_skill(tmp_path)


@pytest.mark.parametrize(
    ("content", "message"),
    [
        ("# Missing", "valid YAML frontmatter"),
        ("---\n[broken\n---\n", "invalid YAML"),
        ("---\n- item\n---\n", "YAML mapping"),
        (
            "---\nname: valid\ndescription: okay\nunknown: true\n---\n",
            "invalid frontmatter fields",
        ),
        ("---\nname: 3\ndescription: okay\n---\n", "invalid frontmatter fields"),
    ],
)
def test_parse_frontmatter_rejects_invalid_content(content: str, message: str) -> None:
    with pytest.raises(SkillValidationError, match=message):
        parse_frontmatter(content)


@pytest.mark.parametrize(
    ("name", "message"),
    [
        ("", "must not be empty"),
        ("a" * 65, "maximum is 64"),
        ("Bad_Name", "lowercase hyphen-case"),
        ("bad--name", "lowercase hyphen-case"),
    ],
)
def test_validate_name_rejects_invalid_names(name: str, message: str) -> None:
    with pytest.raises(SkillValidationError, match=message):
        validate_name(name)


@pytest.mark.parametrize(
    ("description", "message"),
    [
        (" ", "must not be empty"),
        ("x" * 1025, "maximum is 1024"),
        ("Use <files>", "angle brackets"),
    ],
)
def test_validate_description_rejects_invalid_values(
    description: str, message: str
) -> None:
    with pytest.raises(SkillValidationError, match=message):
        validate_description(description)


def test_validate_command_success_and_error(tmp_path: Path) -> None:
    skill = tmp_path / "skill"
    skill.mkdir()
    (skill / "SKILL.md").write_text(skill_document(), encoding="utf-8")
    result = CliRunner().invoke(cli, ["validate", str(skill)])
    assert result.exit_code == 0
    assert result.stdout == "Skill is valid.\n"
    (skill / "SKILL.md").write_text("bad", encoding="utf-8")
    result = CliRunner().invoke(cli, ["validate", str(skill)])
    assert result.exit_code == 1
    assert "valid YAML frontmatter" in result.stderr


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
    assert "Validate Codex" in process.stdout


if __name__ == "__main__":
    cli()
