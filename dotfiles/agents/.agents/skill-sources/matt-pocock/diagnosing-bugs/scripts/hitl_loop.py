#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "pydantic==2.13.4",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""Run a structured human-in-the-loop reproduction plan."""

import contextlib
import io
import os
import subprocess as sp
import sys
import tempfile
import tomllib
from collections.abc import Callable
from pathlib import Path
from typing import Annotated, Literal, Self

import click
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

logger = log.get_logger(__name__)

type LineReader = Callable[[str], str]
type CaptureResult = tuple[str, str]


class PlanError(Exception):
    """Report an invalid or unreadable reproduction plan."""


class InteractionError(Exception):
    """Report an interrupted human-in-the-loop session."""


class StepPrompt(BaseModel):
    """Describe an instruction the human must complete."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    type: Literal["step"]
    instruction: str = Field(min_length=1)


class CapturePrompt(BaseModel):
    """Describe a response to capture for the debugging agent."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    type: Literal["capture"]
    key: str = Field(pattern=r"^[A-Z][A-Z0-9_]*$")
    question: str = Field(min_length=1)
    required: bool = True


type Prompt = Annotated[StepPrompt | CapturePrompt, Field(discriminator="type")]


class LoopPlan(BaseModel):
    """Hold an ordered, validated HITL reproduction plan."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    title: str = Field(min_length=1)
    prompts: tuple[Prompt, ...] = Field(min_length=1)

    @model_validator(mode="after")
    def capture_keys_are_unique(self) -> Self:
        keys = [
            prompt.key for prompt in self.prompts if isinstance(prompt, CapturePrompt)
        ]
        if len(keys) != len(set(keys)):
            raise ValueError("capture keys must be unique")
        return self


def configure_logging() -> None:
    """Send human-readable structured logs to stderr."""
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


def parse_plan(raw: bytes) -> LoopPlan:
    """Parse and validate a UTF-8 TOML reproduction plan."""
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise PlanError("plan must be UTF-8 encoded") from error

    try:
        document: object = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        raise PlanError(f"invalid TOML: {error}") from error

    try:
        return LoopPlan.model_validate(document)
    except ValidationError as error:
        raise PlanError(f"invalid plan: {error}") from error


def load_plan(
    path: Path, read_bytes: Callable[[Path], bytes] = Path.read_bytes
) -> LoopPlan:
    """Load a plan through an injectable filesystem edge."""
    try:
        raw = read_bytes(path)
    except OSError as error:
        raise PlanError(f"cannot read plan {path}: {error}") from error
    return parse_plan(raw)


def render_preview(plan: LoopPlan) -> str:
    """Render the validated interaction sequence without collecting answers."""
    lines = [f"Plan: {plan.title}"]
    for index, prompt in enumerate(plan.prompts, start=1):
        if isinstance(prompt, StepPrompt):
            lines.append(f"{index}. STEP: {prompt.instruction}")
        else:
            requirement = "required" if prompt.required else "optional"
            lines.append(
                f"{index}. CAPTURE {prompt.key} ({requirement}): {prompt.question}"
            )
    return "\n".join(lines)


def read_console_line(prompt: str) -> str:
    """Read one line while keeping interactive prompts off stdout."""
    click.echo(prompt, nl=False, err=True)
    line = sys.stdin.readline()
    if line == "":
        raise InteractionError("input ended before the plan was complete")
    return line.rstrip("\r\n")


def run_loop(plan: LoopPlan, read_line: LineReader) -> tuple[CaptureResult, ...]:
    """Execute the prompt sequence and return captured values."""
    captures: list[CaptureResult] = []
    for prompt in plan.prompts:
        if isinstance(prompt, StepPrompt):
            read_line(f"\n>>> {prompt.instruction}\n    [Enter when done] ")
            continue

        answer = read_line(f"\n>>> {prompt.question}\n    > ")
        while prompt.required and not answer:
            answer = read_line("    A response is required.\n    > ")
        captures.append((prompt.key, answer))
    return tuple(captures)


def render_captures(captures: tuple[CaptureResult, ...]) -> str:
    """Render captures in the original KEY=VALUE machine-readable format."""
    return "\n".join(f"{key}={value}" for key, value in captures)


@click.group()
def cli() -> None:
    """Run structured human-in-the-loop reproduction plans."""
    configure_logging()


@cli.command(name="run")
@click.argument(
    "plan_path",
    type=click.Path(exists=True, dir_okay=False, readable=True, path_type=Path),
)
@click.option(
    "--dry-run",
    is_flag=True,
    help="Validate and preview the plan without prompting for input.",
)
def run_command(plan_path: Path, dry_run: bool) -> None:
    """Run prompts from PLAN_PATH and print captured KEY=VALUE lines."""
    try:
        plan = load_plan(plan_path)
        if dry_run:
            click.echo(render_preview(plan))
            logger.info(
                "plan_previewed", plan=str(plan_path), prompts=len(plan.prompts)
            )
            return
        captures = run_loop(plan, read_console_line)
    except (PlanError, InteractionError) as error:
        raise click.ClickException(str(error)) from error

    if captures:
        click.echo(render_captures(captures))
    logger.info(
        "plan_completed",
        plan=str(plan_path),
        capture_keys=[key for key, _value in captures],
    )


def compact_pytest_output(output: str) -> str:
    """Remove pytest-cov banners while preserving its useful report."""
    lines = []
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


@click.command(name="unit-test")
def _embedded_unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="python-cli-coverage-") as directory:
        coverage_config = Path(directory) / ".coveragerc"
        coverage_config.write_text(
            os.linesep.join(
                (
                    "[run]",
                    "patch = subprocess",
                    "include =",
                    f"    {Path(__file__).resolve().as_posix()}",
                    "",
                )
            ),
            encoding="utf-8",
        )
        previous_coverage_file = os.environ.get("COVERAGE_FILE")
        os.environ["COVERAGE_FILE"] = str(Path(directory) / ".coverage")
        pytest_output = io.StringIO()
        try:
            with contextlib.redirect_stdout(pytest_output):
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
            if previous_coverage_file is None:
                os.environ.pop("COVERAGE_FILE", None)
            else:
                os.environ["COVERAGE_FILE"] = previous_coverage_file
    click.echo(compact_pytest_output(pytest_output.getvalue()), nl=False)
    raise SystemExit(result)


cli.add_command(_embedded_unit_test_command)


VALID_PLAN = b"""\
title = "Export error reproduction"

[[prompts]]
type = "step"
instruction = "Open the app and sign in."

[[prompts]]
type = "capture"
key = "ERRORED"
question = "Did Export throw an error? (y/n)"

[[prompts]]
type = "capture"
key = "ERROR_MSG"
question = "Paste the error message (or none)."
required = false
"""


def test_parse_plan() -> None:
    plan = parse_plan(VALID_PLAN)

    assert plan.title == "Export error reproduction"
    assert len(plan.prompts) == 3
    assert isinstance(plan.prompts[1], CapturePrompt)


def test_parse_plan_rejects_duplicate_capture_keys() -> None:
    duplicate = (
        VALID_PLAN
        + b"""\
[[prompts]]
type = "capture"
key = "ERRORED"
question = "Duplicate?"
"""
    )

    with pytest.raises(PlanError, match="capture keys must be unique"):
        parse_plan(duplicate)


def test_run_loop_preserves_prompt_order_and_capture_format() -> None:
    plan = parse_plan(VALID_PLAN)
    answers = iter(("", "y", "boom"))
    seen_prompts: list[str] = []

    def read_line(prompt: str) -> str:
        seen_prompts.append(prompt)
        return next(answers)

    captures = run_loop(plan, read_line)

    assert len(seen_prompts) == 3
    assert "Open the app" in seen_prompts[0]
    assert render_captures(captures) == "ERRORED=y\nERROR_MSG=boom"


def test_required_capture_reprompts() -> None:
    plan = LoopPlan(
        title="Required",
        prompts=(CapturePrompt(type="capture", key="ANSWER", question="Answer?"),),
    )
    answers = iter(("", "yes"))

    captures = run_loop(plan, lambda _prompt: next(answers))

    assert captures == (("ANSWER", "yes"),)


def test_cli_help_shows_commands() -> None:
    result = CliRunner().invoke(cli, ["--help"])

    assert result.exit_code == 0
    assert "run" in result.stdout
    assert "unit-test" in result.stdout


def test_run_command_dry_run(tmp_path: Path) -> None:
    plan_path = tmp_path / "plan.toml"
    plan_path.write_bytes(VALID_PLAN)

    result = CliRunner().invoke(cli, ["run", str(plan_path), "--dry-run"])

    assert result.exit_code == 0
    assert "Plan: Export error reproduction" in result.stdout
    assert "ERRORED (required)" in result.stdout
    assert "plan_previewed" in result.stderr


def test_run_command_reports_invalid_plan(tmp_path: Path) -> None:
    plan_path = tmp_path / "plan.toml"
    plan_path.write_text("not = [valid", encoding="utf-8")

    result = CliRunner().invoke(cli, ["run", str(plan_path)])

    assert result.exit_code == 1
    assert "invalid TOML" in result.stderr


def test_run_command_separates_captures_and_prompts(tmp_path: Path) -> None:
    plan_path = tmp_path / "plan.toml"
    plan_path.write_bytes(VALID_PLAN)

    result = sp.run(
        [sys.executable, __file__, "run", str(plan_path)],
        input="\ny\nboom\n",
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )

    assert result.returncode == 0
    assert result.stdout == "ERRORED=y\nERROR_MSG=boom\n"
    assert "Open the app and sign in." in result.stderr
    assert "plan_completed" in result.stderr


if __name__ == "__main__":
    cli()
