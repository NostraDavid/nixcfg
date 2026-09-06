#!/usr/bin/env python3

"""Run reproducible activation and task-quality evaluations for skill-review."""

from __future__ import annotations

import argparse
import contextlib
import dataclasses
import datetime as dt
import hashlib
import io
import json
import logging as lg
import os
import re
import shutil
import statistics as stats
import subprocess as sp
import sys
import tempfile
import time as tm
import unittest as ut
from collections.abc import Mapping, Sequence
from pathlib import Path

MINIMUM_PYTHON = (3, 11)
DEFAULT_TIMEOUT_SECONDS = 900
logger = lg.getLogger(__name__)


class EvaluationError(Exception):
    """Report invalid evaluation input or a failed runtime operation."""


@dataclasses.dataclass(frozen=True)
class TriggerCase:
    """One implicit-activation query."""

    case_id: str
    query: str
    should_trigger: bool
    fixture: str | None
    purpose: str
    boundary: bool


@dataclasses.dataclass(frozen=True)
class AssertionSpec:
    """One deterministic task-output check."""

    kind: str
    values: tuple[str, ...]


@dataclasses.dataclass(frozen=True)
class TaskCase:
    """One with-skill versus baseline task."""

    case_id: str
    prompt: str
    expected_output: str
    fixture: str
    assertions: tuple[AssertionSpec, ...]


@dataclasses.dataclass(frozen=True)
class RunResult:
    """Normalized result for one agent invocation."""

    case_id: str
    lane: str
    configuration: str
    attempt: int
    passed: bool
    activated: bool | None
    should_trigger: bool | None
    boundary: bool | None
    exit_code: int
    duration_ms: int
    total_tokens: int | None
    cost_usd: float | None
    final_output: str
    assertion_results: tuple[Mapping[str, object], ...]
    fixture_unchanged: bool
    policy_violations: tuple[str, ...]


def runtime_error() -> str | None:
    """Return a diagnostic when the interpreter is too old."""
    if sys.version_info < MINIMUM_PYTHON:
        required = ".".join(str(part) for part in MINIMUM_PYTHON)
        return f"Python {required} or newer is required"
    return None


def configure_logging() -> None:
    """Send operational logs to stderr."""
    handler = lg.StreamHandler(sys.stderr)
    formatter = lg.Formatter(
        fmt="%(asctime)sZ %(levelname)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )
    formatter.converter = tm.gmtime
    handler.setFormatter(formatter)
    logger.handlers.clear()
    logger.addHandler(handler)
    logger.setLevel(lg.INFO)
    logger.propagate = False


def load_json(path: Path) -> object:
    """Load JSON with a path-aware error."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise EvaluationError(f"missing file: {path}") from error
    except json.JSONDecodeError as error:
        raise EvaluationError(
            f"invalid JSON in {path}:{error.lineno}:{error.colno}: {error.msg}"
        ) from error


def require_mapping(value: object, context: str) -> Mapping[str, object]:
    """Return a mapping or raise a concise validation error."""
    if not isinstance(value, dict):
        raise EvaluationError(f"{context} must be an object")
    return value


def require_string(value: object, context: str) -> str:
    """Return a non-empty string."""
    if not isinstance(value, str) or not value.strip():
        raise EvaluationError(f"{context} must be a non-empty string")
    return value


def require_bool(value: object, context: str) -> bool:
    """Return a boolean without accepting integers."""
    if not isinstance(value, bool):
        raise EvaluationError(f"{context} must be a boolean")
    return value


def load_trigger_cases(path: Path) -> tuple[TriggerCase, ...]:
    """Parse and validate a trigger query file."""
    document = require_mapping(load_json(path), str(path))
    raw_cases = document.get("queries")
    if not isinstance(raw_cases, list) or not raw_cases:
        raise EvaluationError(f"{path}: queries must be a non-empty array")
    cases: list[TriggerCase] = []
    seen: set[str] = set()
    for index, raw_case in enumerate(raw_cases):
        context = f"{path}:queries[{index}]"
        case = require_mapping(raw_case, context)
        case_id = require_string(case.get("id"), f"{context}.id")
        if case_id in seen:
            raise EvaluationError(f"{path}: duplicate id: {case_id}")
        seen.add(case_id)
        fixture_value = case.get("fixture")
        if fixture_value is not None and not isinstance(fixture_value, str):
            raise EvaluationError(f"{context}.fixture must be a string or null")
        cases.append(
            TriggerCase(
                case_id=case_id,
                query=require_string(case.get("query"), f"{context}.query"),
                should_trigger=require_bool(
                    case.get("should_trigger"), f"{context}.should_trigger"
                ),
                fixture=fixture_value,
                purpose=require_string(case.get("purpose"), f"{context}.purpose"),
                boundary=require_bool(
                    case.get("boundary", False), f"{context}.boundary"
                ),
            )
        )
    return tuple(cases)


def load_assertion(raw: object, context: str) -> AssertionSpec:
    """Parse one supported deterministic assertion."""
    assertion = require_mapping(raw, context)
    kind = require_string(assertion.get("kind"), f"{context}.kind")
    supported = {
        "contains_all",
        "contains_any",
        "not_contains",
        "regex",
        "fixture_unchanged",
        "exit_code_zero",
    }
    if kind not in supported:
        raise EvaluationError(f"{context}.kind is unsupported: {kind}")
    raw_values = assertion.get("values", [])
    if not isinstance(raw_values, list) or not all(
        isinstance(value, str) and value for value in raw_values
    ):
        raise EvaluationError(f"{context}.values must be an array of strings")
    values = tuple(raw_values)
    if kind in {"contains_all", "contains_any", "not_contains", "regex"} and not values:
        raise EvaluationError(f"{context}.values must not be empty for {kind}")
    if kind in {"fixture_unchanged", "exit_code_zero"} and values:
        raise EvaluationError(f"{context}.values must be empty for {kind}")
    return AssertionSpec(kind=kind, values=values)


def load_task_cases(path: Path) -> tuple[TaskCase, ...]:
    """Parse and validate task-quality evals."""
    document = require_mapping(load_json(path), str(path))
    if document.get("skill_name") != "skill-review":
        raise EvaluationError(f"{path}: skill_name must be skill-review")
    raw_cases = document.get("evals")
    if not isinstance(raw_cases, list) or not raw_cases:
        raise EvaluationError(f"{path}: evals must be a non-empty array")
    cases: list[TaskCase] = []
    seen: set[str] = set()
    for index, raw_case in enumerate(raw_cases):
        context = f"{path}:evals[{index}]"
        case = require_mapping(raw_case, context)
        case_id = require_string(case.get("id"), f"{context}.id")
        if case_id in seen:
            raise EvaluationError(f"{path}: duplicate id: {case_id}")
        seen.add(case_id)
        raw_assertions = case.get("assertions")
        if not isinstance(raw_assertions, list) or not raw_assertions:
            raise EvaluationError(f"{context}.assertions must be a non-empty array")
        cases.append(
            TaskCase(
                case_id=case_id,
                prompt=require_string(case.get("prompt"), f"{context}.prompt"),
                expected_output=require_string(
                    case.get("expected_output"), f"{context}.expected_output"
                ),
                fixture=require_string(case.get("fixture"), f"{context}.fixture"),
                assertions=tuple(
                    load_assertion(value, f"{context}.assertions[{assertion_index}]")
                    for assertion_index, value in enumerate(raw_assertions)
                ),
            )
        )
    return tuple(cases)


def skill_paths(skill_dir: Path) -> tuple[Path, Path, Path]:
    """Return canonical eval resource paths."""
    evals_dir = skill_dir / "evals"
    return (
        evals_dir / "trigger" / "train.json",
        evals_dir / "trigger" / "validation.json",
        evals_dir / "evals.json",
    )


def validate_resources(skill_dir: Path) -> Mapping[str, int]:
    """Validate configs and referenced fixture paths without writing."""
    if not (skill_dir / "SKILL.md").is_file():
        raise EvaluationError(f"missing SKILL.md in {skill_dir}")
    train_path, validation_path, tasks_path = skill_paths(skill_dir)
    train = load_trigger_cases(train_path)
    validation = load_trigger_cases(validation_path)
    tasks = load_task_cases(tasks_path)
    fixtures_dir = skill_dir / "evals" / "files"
    fixture_names = {
        case.fixture for case in (*train, *validation) if case.fixture is not None
    }
    fixture_names.update(case.fixture for case in tasks)
    for fixture_name in fixture_names:
        fixture_path = fixtures_dir / fixture_name
        if not fixture_path.is_dir():
            raise EvaluationError(f"missing fixture directory: {fixture_path}")
    overlap = {case.case_id for case in train} & {case.case_id for case in validation}
    if overlap:
        raise EvaluationError(
            f"trigger train and validation ids overlap: {', '.join(sorted(overlap))}"
        )
    return {
        "train_queries": len(train),
        "validation_queries": len(validation),
        "task_evals": len(tasks),
        "fixtures": len(fixture_names),
    }


def snapshot_tree(root: Path) -> Mapping[str, str]:
    """Hash a fixture tree for mutation detection."""
    snapshot: dict[str, str] = {}
    for path in sorted(root.rglob("*")):
        if path.is_file():
            relative = path.relative_to(root).as_posix()
            snapshot[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return snapshot


def tree_revision(root: Path) -> str:
    """Hash file names and contents for a stable tree revision."""
    digest = hashlib.sha256()
    for relative, checksum in snapshot_tree(root).items():
        digest.update(relative.encode())
        digest.update(b"\0")
        digest.update(checksum.encode())
        digest.update(b"\n")
    return digest.hexdigest()


def detect_activation(
    events: str, activated_skill_md: Path, runtime: str = "vibe"
) -> bool:
    """Detect runtime-specific evidence that the exact project copy was loaded."""
    expected_dir = str(activated_skill_md.resolve().parent)
    marker = '<skill_content name="skill-review">'
    for line in events.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(event, dict):
            continue
        if runtime == "vibe":
            if event.get("role") != "tool" or event.get("name") != "skill":
                continue
            content = event.get("content")
            if not isinstance(content, str) or marker not in content:
                continue
            if f"skill_dir: {expected_dir}" in content:
                return True
        elif runtime == "codex" and codex_event_reads_path(
            event, activated_skill_md.resolve()
        ):
            return True
    return False


def codex_event_reads_path(event: Mapping[str, object], expected: Path) -> bool:
    """Accept only a Codex tool/command event that reads the exact SKILL.md."""
    serialized = json.dumps(event, ensure_ascii=False).replace("\\/", "/")
    if str(expected) not in serialized:
        return False
    event_type = str(event.get("type", "")).casefold()
    if not any(term in event_type for term in ("tool", "command", "item")):
        return False
    return any(
        pattern in serialized.casefold()
        for pattern in ('"read"', "ctx_read", "sed ", "cat ", "head ", "tail ")
    )


def extract_total_tokens(events: str) -> int | None:
    """Extract the largest completed token total exposed in Codex JSONL."""
    totals: list[int] = []

    def visit(value: object) -> None:
        if isinstance(value, dict):
            usage = value.get("usage")
            if isinstance(usage, dict):
                total = usage.get("total_tokens")
                if isinstance(total, int):
                    totals.append(total)
                else:
                    input_tokens = usage.get("input_tokens")
                    output_tokens = usage.get("output_tokens")
                    if isinstance(input_tokens, int) and isinstance(output_tokens, int):
                        totals.append(input_tokens + output_tokens)
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    for line in events.splitlines():
        try:
            visit(json.loads(line))
        except json.JSONDecodeError:
            continue
    return max(totals) if totals else None


def grade_assertions(
    specs: Sequence[AssertionSpec],
    output: str,
    exit_code: int,
    fixture_before: Mapping[str, str],
    fixture_after: Mapping[str, str],
) -> tuple[Mapping[str, object], ...]:
    """Grade deterministic output and mutation assertions."""
    lowered = output.casefold()
    results: list[Mapping[str, object]] = []
    for spec in specs:
        if spec.kind == "contains_all":
            missing = [
                value for value in spec.values if value.casefold() not in lowered
            ]
            passed = not missing
            evidence = "all terms found" if passed else f"missing: {', '.join(missing)}"
        elif spec.kind == "contains_any":
            found = [value for value in spec.values if value.casefold() in lowered]
            passed = bool(found)
            evidence = f"found: {', '.join(found)}" if found else "no term found"
        elif spec.kind == "not_contains":
            found = [value for value in spec.values if value.casefold() in lowered]
            passed = not found
            evidence = (
                "no prohibited terms found" if passed else f"found: {', '.join(found)}"
            )
        elif spec.kind == "regex":
            found_patterns = [
                pattern
                for pattern in spec.values
                if re.search(pattern, output, flags=re.IGNORECASE | re.MULTILINE)
            ]
            passed = len(found_patterns) == len(spec.values)
            evidence = (
                "all patterns matched"
                if passed
                else f"unmatched: {', '.join(set(spec.values) - set(found_patterns))}"
            )
        elif spec.kind == "fixture_unchanged":
            passed = fixture_before == fixture_after
            evidence = "fixture unchanged" if passed else "fixture changed"
        elif spec.kind == "exit_code_zero":
            passed = exit_code == 0
            evidence = f"exit_code={exit_code}"
        else:
            raise AssertionError(f"unhandled assertion kind: {spec.kind}")
        results.append(
            {
                "kind": spec.kind,
                "values": list(spec.values),
                "passed": passed,
                "evidence": evidence,
            }
        )
    return tuple(results)


def configure_vibe_workspace(workdir: Path, enable_project_skill: bool) -> None:
    """Restrict Vibe to the project skill or to an empty baseline allowlist."""
    config_dir = workdir / ".vibe"
    config_dir.mkdir()
    enabled = "skill-review" if enable_project_skill else "__baseline_no_skills__"
    (config_dir / "config.toml").write_text(
        f'enabled_skills = ["{enabled}"]\n'
        "experimental_enable_registry_skills = false\n",
        encoding="utf-8",
    )


def toml_quote(value: Path) -> str:
    """Quote a path for a Codex CLI TOML override."""
    escaped = str(value).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def external_skill_candidates(skill_dir: Path) -> tuple[Path, ...]:
    """Find common installed aliases that could contaminate a Codex baseline."""
    candidates = [
        skill_dir / "SKILL.md",
        Path.home() / ".agents" / "skills" / "skill-review" / "SKILL.md",
        Path.home() / ".codex" / "skills" / "skill-review" / "SKILL.md",
    ]
    return tuple(path for path in candidates if path.exists())


def skill_config_override(
    project_skill_md: Path,
    external_paths: Sequence[Path],
    enable_project_skill: bool,
) -> str:
    """Build a deterministic per-path Codex skills.config override."""
    entries = [
        f"{{path={toml_quote(path)},enabled=false}}"
        for path in external_paths
        if path != project_skill_md
    ]
    entries.append(
        f"{{path={toml_quote(project_skill_md)},"
        f"enabled={'true' if enable_project_skill else 'false'}}}"
    )
    return f"skills.config=[{','.join(entries)}]"


def copy_skill_for_run(skill_dir: Path, workdir: Path) -> Path:
    """Install an isolated project-level copy of the skill."""
    destination = workdir / ".agents" / "skills" / "skill-review"
    shutil.copytree(
        skill_dir,
        destination,
        ignore=shutil.ignore_patterns("evals", "scripts", "__pycache__"),
    )
    return destination / "SKILL.md"


def copy_fixture(skill_dir: Path, fixture_name: str, workdir: Path) -> Path:
    """Copy one fixture into an isolated run directory."""
    source = skill_dir / "evals" / "files" / fixture_name
    destination = workdir / "fixture"
    shutil.copytree(source, destination)
    return destination


def render_prompt(prompt: str, fixture_path: Path | None) -> str:
    """Replace the stable fixture placeholder."""
    if fixture_path is None:
        return prompt
    rendered = prompt.replace("{fixture}", str(fixture_path))
    if "{fixture}" not in prompt:
        rendered = f"{prompt}\n\nInput fixture: {fixture_path}"
    return rendered


def extract_final_output(events: str) -> str:
    """Return the last non-empty assistant message from Vibe streaming JSON."""
    outputs: list[str] = []
    for line in events.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(event, dict) or event.get("role") != "assistant":
            item = event.get("item")
            if not isinstance(item, dict) or item.get("type") != "agent_message":
                continue
            content = item.get("text")
        else:
            content = event.get("content")
        if isinstance(content, str) and content.strip():
            outputs.append(content)
    return outputs[-1] if outputs else ""


def invoke_vibe(
    prompt: str,
    workdir: Path,
    enable_project_skill: bool,
    model: str | None,
    timeout_seconds: int,
) -> tuple[int, str, str, int]:
    """Run one bounded Vibe invocation with read-only tools."""
    configure_vibe_workspace(workdir, enable_project_skill)
    command = [
        "vibe",
        "--prompt",
        prompt,
        "--output",
        "streaming",
        "--max-turns",
        "20",
        "--max-price",
        "1.00",
        "--agent",
        "plan",
        "--enabled-tools",
        "skill",
        "--enabled-tools",
        "read_file",
        "--enabled-tools",
        "grep",
        "--workdir",
        str(workdir),
        "--trust",
    ]
    environment = os.environ.copy()
    if model is not None:
        environment["VIBE_ACTIVE_MODEL"] = model
    started = tm.monotonic()
    try:
        completed = sp.run(
            command,
            cwd=workdir,
            text=True,
            stdout=sp.PIPE,
            stderr=sp.PIPE,
            env=environment,
            timeout=timeout_seconds,
            check=False,
        )
    except sp.TimeoutExpired as error:
        duration_ms = round((tm.monotonic() - started) * 1000)
        stdout = error.stdout if isinstance(error.stdout, str) else ""
        stderr = error.stderr if isinstance(error.stderr, str) else ""
        return 124, stdout, f"{stderr}\nError: Vibe run timed out", duration_ms
    duration_ms = round((tm.monotonic() - started) * 1000)
    return completed.returncode, completed.stdout, completed.stderr, duration_ms


def invoke_codex(
    prompt: str,
    workdir: Path,
    project_skill_md: Path,
    external_paths: Sequence[Path],
    enable_project_skill: bool,
    model: str | None,
    timeout_seconds: int,
) -> tuple[int, str, str, int]:
    """Run one isolated Codex invocation in its read-only sandbox."""
    command = [
        "codex",
        "exec",
        "--json",
        "--ephemeral",
        "--skip-git-repo-check",
        "--sandbox",
        "read-only",
        "--cd",
        str(workdir),
        "--config",
        skill_config_override(project_skill_md, external_paths, enable_project_skill),
    ]
    if model is not None:
        command.extend(["--model", model])
    command.append(prompt)
    started = tm.monotonic()
    try:
        completed = sp.run(
            command,
            cwd=workdir,
            text=True,
            stdout=sp.PIPE,
            stderr=sp.PIPE,
            timeout=timeout_seconds,
            check=False,
        )
    except sp.TimeoutExpired as error:
        duration_ms = round((tm.monotonic() - started) * 1000)
        stdout = error.stdout if isinstance(error.stdout, str) else ""
        stderr = error.stderr if isinstance(error.stderr, str) else ""
        return 124, stdout, f"{stderr}\nError: Codex run timed out", duration_ms
    duration_ms = round((tm.monotonic() - started) * 1000)
    return completed.returncode, completed.stdout, completed.stderr, duration_ms


def invoke_runtime(
    runtime: str,
    prompt: str,
    workdir: Path,
    project_skill_md: Path,
    skill_dir: Path,
    enable_project_skill: bool,
    model: str | None,
    timeout_seconds: int,
) -> tuple[int, str, str, int]:
    """Dispatch one evaluation call to the selected supported runtime."""
    if runtime == "vibe":
        return invoke_vibe(
            prompt,
            workdir,
            enable_project_skill,
            model,
            timeout_seconds,
        )
    if runtime == "codex":
        return invoke_codex(
            prompt,
            workdir,
            project_skill_md,
            external_skill_candidates(skill_dir),
            enable_project_skill,
            model,
            timeout_seconds,
        )
    raise EvaluationError(f"unsupported runtime: {runtime}")


def write_json(path: Path, value: object) -> None:
    """Write stable JSON result data."""
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def result_to_json(result: RunResult) -> Mapping[str, object]:
    """Serialize a normalized run result."""
    return dataclasses.asdict(result)


def run_trigger_case(
    skill_dir: Path,
    case: TriggerCase,
    split: str,
    attempt: int,
    iteration_dir: Path,
    runtime: str,
    model: str | None,
    timeout_seconds: int,
) -> RunResult:
    """Execute and persist one trigger query."""
    run_dir = iteration_dir / "trigger" / split / case.case_id / f"attempt-{attempt}"
    workdir = run_dir / "workdir"
    workdir.mkdir(parents=True)
    project_skill_md = copy_skill_for_run(skill_dir, workdir)
    fixture_path = (
        copy_fixture(skill_dir, case.fixture, workdir)
        if case.fixture is not None
        else None
    )
    fixture_before = snapshot_tree(fixture_path) if fixture_path is not None else {}
    prompt = render_prompt(case.query, fixture_path)
    exit_code, events, stderr, duration_ms = invoke_runtime(
        runtime=runtime,
        prompt=prompt,
        workdir=workdir,
        project_skill_md=project_skill_md,
        skill_dir=skill_dir,
        enable_project_skill=True,
        model=model,
        timeout_seconds=timeout_seconds,
    )
    (run_dir / "events.jsonl").write_text(events, encoding="utf-8")
    (run_dir / "stderr.txt").write_text(stderr, encoding="utf-8")
    final_output = extract_final_output(events)
    (run_dir / "final.txt").write_text(final_output, encoding="utf-8")
    activated = detect_activation(events, project_skill_md, runtime)
    fixture_after = snapshot_tree(fixture_path) if fixture_path is not None else {}
    fixture_unchanged = fixture_before == fixture_after
    result = RunResult(
        case_id=case.case_id,
        lane="trigger",
        configuration=split,
        attempt=attempt,
        passed=exit_code == 0
        and activated == case.should_trigger
        and fixture_unchanged,
        activated=activated,
        should_trigger=case.should_trigger,
        boundary=case.boundary,
        exit_code=exit_code,
        duration_ms=duration_ms,
        total_tokens=extract_total_tokens(events),
        cost_usd=None,
        final_output=final_output,
        assertion_results=(),
        fixture_unchanged=fixture_unchanged,
        policy_violations=(),
    )
    write_json(run_dir / "result.json", result_to_json(result))
    return result


def run_task_case(
    skill_dir: Path,
    case: TaskCase,
    configuration: str,
    attempt: int,
    iteration_dir: Path,
    runtime: str,
    model: str | None,
    timeout_seconds: int,
) -> RunResult:
    """Execute and persist one task-quality configuration."""
    run_dir = (
        iteration_dir / "task" / case.case_id / configuration / f"attempt-{attempt}"
    )
    workdir = run_dir / "workdir"
    workdir.mkdir(parents=True)
    project_skill_md = (
        copy_skill_for_run(skill_dir, workdir)
        if configuration == "with_skill"
        else workdir / ".agents" / "skills" / "skill-review" / "SKILL.md"
    )
    fixture_path = copy_fixture(skill_dir, case.fixture, workdir)
    fixture_before = snapshot_tree(fixture_path)
    prompt = render_prompt(case.prompt, fixture_path)
    exit_code, events, stderr, duration_ms = invoke_runtime(
        runtime=runtime,
        prompt=prompt,
        workdir=workdir,
        project_skill_md=project_skill_md,
        skill_dir=skill_dir,
        enable_project_skill=configuration == "with_skill",
        model=model,
        timeout_seconds=timeout_seconds,
    )
    (run_dir / "events.jsonl").write_text(events, encoding="utf-8")
    (run_dir / "stderr.txt").write_text(stderr, encoding="utf-8")
    final_output = extract_final_output(events)
    (run_dir / "final.txt").write_text(final_output, encoding="utf-8")
    fixture_after = snapshot_tree(fixture_path)
    assertion_results = grade_assertions(
        case.assertions,
        final_output,
        exit_code,
        fixture_before,
        fixture_after,
    )
    activated = detect_activation(events, project_skill_md, runtime)
    result = RunResult(
        case_id=case.case_id,
        lane="task",
        configuration=configuration,
        attempt=attempt,
        passed=all(bool(item["passed"]) for item in assertion_results),
        activated=activated,
        should_trigger=True if configuration == "with_skill" else False,
        boundary=None,
        exit_code=exit_code,
        duration_ms=duration_ms,
        total_tokens=extract_total_tokens(events),
        cost_usd=None,
        final_output=final_output,
        assertion_results=assertion_results,
        fixture_unchanged=fixture_before == fixture_after,
        policy_violations=(),
    )
    write_json(run_dir / "grading.json", {"assertion_results": assertion_results})
    write_json(
        run_dir / "timing.json",
        {
            "duration_ms": duration_ms,
            "total_tokens": extract_total_tokens(events),
        },
    )
    write_json(run_dir / "result.json", result_to_json(result))
    return result


def selected_trigger_cases(
    skill_dir: Path, split: str, case_ids: Sequence[str] | None
) -> tuple[tuple[str, TriggerCase], ...]:
    """Select trigger cases while retaining their split."""
    train_path, validation_path, _ = skill_paths(skill_dir)
    selected: list[tuple[str, TriggerCase]] = []
    if split in {"train", "all"}:
        selected.extend(("train", case) for case in load_trigger_cases(train_path))
    if split in {"validation", "all"}:
        selected.extend(
            ("validation", case) for case in load_trigger_cases(validation_path)
        )
    if case_ids:
        selected = [
            (case_split, case)
            for case_split, case in selected
            if case.case_id in case_ids
        ]
    return tuple(selected)


def build_plan(
    skill_dir: Path,
    suite: str,
    split: str,
    attempts: int,
    case_ids: Sequence[str] | None = None,
) -> Mapping[str, object]:
    """Build a mutation-free execution plan."""
    validate_resources(skill_dir)
    trigger_cases = (
        selected_trigger_cases(skill_dir, split, case_ids)
        if suite in {"trigger", "all"}
        else ()
    )
    _, _, tasks_path = skill_paths(skill_dir)
    task_cases = load_task_cases(tasks_path) if suite in {"task", "all"} else ()
    if case_ids:
        task_cases = tuple(case for case in task_cases if case.case_id in case_ids)
        selected_ids = {case.case_id for _, case in trigger_cases}
        selected_ids.update(case.case_id for case in task_cases)
        missing = set(case_ids) - selected_ids
        if missing:
            raise EvaluationError(
                f"selected case ids not found in suite/split: {', '.join(sorted(missing))}"
            )
    trigger_runs = len(trigger_cases) * attempts
    task_runs = len(task_cases) * attempts * 2
    return {
        "suite": suite,
        "split": split,
        "attempts": attempts,
        "trigger_cases": len(trigger_cases),
        "task_cases": len(task_cases),
        "trigger_runs": trigger_runs,
        "task_runs": task_runs,
        "total_runtime_runs": trigger_runs + task_runs,
    }


def aggregate_results(iteration_dir: Path) -> Mapping[str, object]:
    """Aggregate retained per-run result files."""
    result_paths = sorted(iteration_dir.rglob("result.json"))
    if not result_paths:
        raise EvaluationError(f"no result.json files found under {iteration_dir}")
    rows = [require_mapping(load_json(path), str(path)) for path in result_paths]
    trigger_rows = [row for row in rows if row.get("lane") == "trigger"]
    task_rows = [row for row in rows if row.get("lane") == "task"]

    def rate(items: Sequence[Mapping[str, object]]) -> float | None:
        if not items:
            return None
        return sum(bool(item.get("passed")) for item in items) / len(items)

    positive = [row for row in trigger_rows if row.get("should_trigger") is True]
    negative = [row for row in trigger_rows if row.get("should_trigger") is False]
    validation = [
        row for row in trigger_rows if row.get("configuration") == "validation"
    ]
    validation_positive = [
        row for row in validation if row.get("should_trigger") is True
    ]
    validation_negative = [
        row for row in validation if row.get("should_trigger") is False
    ]
    boundary = [row for row in trigger_rows if row.get("boundary") is True]
    with_skill = [row for row in task_rows if row.get("configuration") == "with_skill"]
    without_skill = [
        row for row in task_rows if row.get("configuration") == "without_skill"
    ]
    durations = [
        int(row["duration_ms"])
        for row in rows
        if isinstance(row.get("duration_ms"), int)
    ]
    tokens = [
        int(row["total_tokens"])
        for row in rows
        if isinstance(row.get("total_tokens"), int)
    ]
    attempts_per_case: dict[str, int] = {}
    for row in rows:
        key = ":".join(
            (
                str(row.get("lane")),
                str(row.get("configuration")),
                str(row.get("case_id")),
            )
        )
        attempts_per_case[key] = attempts_per_case.get(key, 0) + 1
    failed_assertions = [
        {
            "case_id": row.get("case_id"),
            "configuration": row.get("configuration"),
            "attempt": row.get("attempt"),
            "assertion": assertion,
        }
        for row in task_rows
        for assertion in row.get("assertion_results", [])
        if isinstance(assertion, dict) and assertion.get("passed") is False
    ]
    policy_violations = [
        violation
        for row in rows
        for violation in row.get("policy_violations", [])
        if isinstance(violation, str)
    ]
    unauthorized_mutations = sum(row.get("fixture_unchanged") is False for row in rows)
    with_rate = rate(with_skill)
    without_rate = rate(without_skill)
    benchmark = {
        "runs": len(rows),
        "trigger": {
            "positive_recall": rate(positive),
            "negative_specificity": rate(negative),
            "validation_positive_recall": rate(validation_positive),
            "validation_negative_specificity": rate(validation_negative),
            "boundary_accuracy": rate(boundary),
            "total": len(trigger_rows),
        },
        "task": {
            "with_skill_pass_rate": with_rate,
            "without_skill_pass_rate": without_rate,
            "pass_rate_delta": (
                with_rate - without_rate
                if with_rate is not None and without_rate is not None
                else None
            ),
            "total": len(task_rows),
        },
        "timing": {
            "median_duration_ms": stats.median(durations) if durations else None,
            "max_duration_ms": max(durations) if durations else None,
            "median_total_tokens": stats.median(tokens) if tokens else None,
            "max_total_tokens": max(tokens) if tokens else None,
        },
        "operations": {
            "attempts_per_case": attempts_per_case,
            "minimum_attempts_per_case": min(attempts_per_case.values()),
            "failed_assertions": failed_assertions,
            "unauthorized_mutations": unauthorized_mutations,
            "policy_violations": policy_violations,
        },
    }
    benchmark["release_gate"] = {
        "minimum_five_attempts": min(attempts_per_case.values()) >= 5,
        "validation_positive_recall_at_least_95_percent": (
            rate(validation_positive) is not None and rate(validation_positive) >= 0.95
        ),
        "validation_negative_specificity_at_least_95_percent": (
            rate(validation_negative) is not None and rate(validation_negative) >= 0.95
        ),
        "boundary_accuracy_100_percent": (
            rate(boundary) is not None and rate(boundary) == 1.0
        ),
        "with_skill_task_pass_rate_at_least_90_percent": (
            with_rate is not None and with_rate >= 0.90
        ),
        "with_skill_not_below_baseline": (
            with_rate is not None
            and without_rate is not None
            and with_rate >= without_rate
        ),
        "zero_unauthorized_mutations": unauthorized_mutations == 0,
        "zero_policy_violations": not policy_violations,
        "all_assertions_passed_or_dispositioned": not failed_assertions,
    }
    benchmark["release_gate"]["passed"] = all(benchmark["release_gate"].values())
    return benchmark


def run_evaluations(arguments: argparse.Namespace) -> int:
    """Execute a confirmed evaluation iteration."""
    skill_dir = arguments.skill_dir.resolve()
    plan = build_plan(
        skill_dir,
        arguments.suite,
        arguments.split,
        arguments.attempts,
        arguments.case_ids,
    )
    if arguments.dry_run:
        print(json.dumps(plan, indent=2, sort_keys=True))
        return 0
    if not arguments.yes:
        raise EvaluationError("run requires --yes; use --dry-run to preview")
    timestamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    iteration_dir = arguments.workspace.resolve() / f"iteration-{timestamp}"
    if iteration_dir.is_relative_to(skill_dir):
        raise EvaluationError("workspace must be outside the skill directory")
    iteration_dir.mkdir(parents=True)
    write_json(iteration_dir / "plan.json", plan)
    results: list[RunResult] = []
    if arguments.suite in {"trigger", "all"}:
        for split, case in selected_trigger_cases(
            skill_dir, arguments.split, arguments.case_ids
        ):
            for attempt in range(1, arguments.attempts + 1):
                logger.info(
                    "trigger_run_started case=%s split=%s attempt=%d",
                    case.case_id,
                    split,
                    attempt,
                )
                results.append(
                    run_trigger_case(
                        skill_dir,
                        case,
                        split,
                        attempt,
                        iteration_dir,
                        arguments.runtime,
                        arguments.model,
                        arguments.timeout,
                    )
                )
    if arguments.suite in {"task", "all"}:
        _, _, tasks_path = skill_paths(skill_dir)
        task_cases = load_task_cases(tasks_path)
        if arguments.case_ids:
            task_cases = tuple(
                case for case in task_cases if case.case_id in arguments.case_ids
            )
        for case in task_cases:
            for configuration in ("with_skill", "without_skill"):
                for attempt in range(1, arguments.attempts + 1):
                    logger.info(
                        "task_run_started case=%s configuration=%s attempt=%d",
                        case.case_id,
                        configuration,
                        attempt,
                    )
                    results.append(
                        run_task_case(
                            skill_dir,
                            case,
                            configuration,
                            attempt,
                            iteration_dir,
                            arguments.runtime,
                            arguments.model,
                            arguments.timeout,
                        )
                    )
    benchmark = aggregate_results(iteration_dir)
    write_json(iteration_dir / "benchmark.json", benchmark)
    write_json(
        iteration_dir / "run-metadata.json",
        {
            "created_at": timestamp,
            "agent": "plan" if arguments.runtime == "vibe" else "codex-default",
            "model": arguments.model,
            "python": sys.version,
            "runtime": sp.run(
                [arguments.runtime, "--version"],
                text=True,
                stdout=sp.PIPE,
                stderr=sp.STDOUT,
                check=False,
            ).stdout.strip(),
            "tool_set": (
                ["skill", "read_file", "grep"]
                if arguments.runtime == "vibe"
                else ["codex-read-only-sandbox"]
            ),
            "skill_revision": tree_revision(skill_dir),
            "fixture_revisions": {
                path.name: tree_revision(path)
                for path in sorted((skill_dir / "evals" / "files").iterdir())
                if path.is_dir()
            },
            "attempts": arguments.attempts,
            "cost_usd": None,
        },
    )
    print(iteration_dir)
    return 0 if all(result.passed for result in results) else 1


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser without business side effects."""
    default_skill_dir = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description="Evaluate skill-review activation and task quality."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    validate_parser = commands.add_parser(
        "validate", help="Validate eval definitions and fixture references."
    )
    validate_parser.add_argument("--skill-dir", type=Path, default=default_skill_dir)

    plan_parser = commands.add_parser("plan", help="Print the planned Codex runs.")
    add_selection_arguments(plan_parser, default_skill_dir)

    run_parser = commands.add_parser(
        "run", help="Run Codex evals and persist an isolated iteration."
    )
    add_selection_arguments(run_parser, default_skill_dir)
    run_parser.add_argument("--workspace", type=Path, required=True)
    run_parser.add_argument("--runtime", choices=("vibe", "codex"), default="vibe")
    run_parser.add_argument("--model", help="Optional runtime model override.")
    run_parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="Per-run Vibe timeout in seconds (default: %(default)s).",
    )
    run_parser.add_argument(
        "--dry-run", action="store_true", help="Validate and print the plan only."
    )
    run_parser.add_argument(
        "--yes", action="store_true", help="Confirm model calls and result writes."
    )

    aggregate_parser = commands.add_parser(
        "aggregate", help="Aggregate an existing iteration."
    )
    aggregate_parser.add_argument("iteration_dir", type=Path)

    check_parser = commands.add_parser("check", help="Verify runtime readiness.")
    check_parser.add_argument("--skill-dir", type=Path, default=default_skill_dir)
    check_parser.add_argument("--runtime", choices=("vibe", "codex"), default="vibe")
    commands.add_parser("unit-test", help="Run embedded unit tests.")
    return parser


def add_selection_arguments(
    parser: argparse.ArgumentParser, default_skill_dir: Path
) -> None:
    """Add shared eval-selection arguments."""
    parser.add_argument("--skill-dir", type=Path, default=default_skill_dir)
    parser.add_argument("--suite", choices=("trigger", "task", "all"), default="all")
    parser.add_argument(
        "--split", choices=("train", "validation", "all"), default="all"
    )
    parser.add_argument("--attempts", type=int, default=3)
    parser.add_argument(
        "--case",
        dest="case_ids",
        action="append",
        help="Run one case id; repeat to select multiple cases.",
    )


def run_check(skill_dir: Path, runtime: str) -> int:
    """Verify runtime and all required local inputs."""
    error = runtime_error()
    if error is not None:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    if shutil.which(runtime) is None:
        print(f"Error: {runtime} executable not found on PATH", file=sys.stderr)
        return 1
    try:
        validate_resources(skill_dir.resolve())
    except EvaluationError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    print("ok")
    return 0


def run_unit_tests() -> int:
    """Run tests from this file without external test dependencies."""
    suite = ut.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = ut.TextTestRunner(stream=sys.stdout, verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


def main(argv: Sequence[str] | None = None) -> int:
    """Parse arguments, dispatch, and translate expected failures."""
    error = runtime_error()
    if error is not None:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    arguments = build_parser().parse_args(list(argv) if argv is not None else None)
    configure_logging()
    try:
        if arguments.command == "validate":
            summary = validate_resources(arguments.skill_dir.resolve())
            print(json.dumps(summary, indent=2, sort_keys=True))
            return 0
        if arguments.command == "plan":
            if arguments.attempts < 1:
                raise EvaluationError("attempts must be at least 1")
            print(
                json.dumps(
                    build_plan(
                        arguments.skill_dir.resolve(),
                        arguments.suite,
                        arguments.split,
                        arguments.attempts,
                        arguments.case_ids,
                    ),
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        if arguments.command == "run":
            if arguments.attempts < 1:
                raise EvaluationError("attempts must be at least 1")
            if arguments.timeout < 1:
                raise EvaluationError("timeout must be at least 1")
            return run_evaluations(arguments)
        if arguments.command == "aggregate":
            print(
                json.dumps(
                    aggregate_results(arguments.iteration_dir.resolve()),
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        if arguments.command == "check":
            return run_check(arguments.skill_dir, arguments.runtime)
        if arguments.command == "unit-test":
            return run_unit_tests()
    except EvaluationError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    raise AssertionError(f"unhandled command: {arguments.command}")


class ScriptTests(ut.TestCase):
    """Exercise parsing, grading, detection, and dry-run safety."""

    def test_detect_vibe_activation_uses_skill_tool_result(self) -> None:
        path = Path("/tmp/project/.agents/skills/skill-review/SKILL.md")
        events = json.dumps(
            {
                "role": "tool",
                "name": "skill",
                "content": (
                    f'<skill_content name="skill-review">\nskill_dir: {path.parent}'
                ),
            }
        )
        self.assertTrue(detect_activation(events, path))
        self.assertFalse(detect_activation("skill-review mentioned", path))

    def test_detect_codex_activation_rejects_plain_path_mention(self) -> None:
        path = Path("/tmp/project/.agents/skills/skill-review/SKILL.md")
        mention = json.dumps({"type": "agent_message", "text": str(path)})
        read_event = json.dumps(
            {"type": "item.completed", "item": {"command": f"cat {path}"}}
        )
        self.assertFalse(detect_activation(mention, path, "codex"))
        self.assertTrue(detect_activation(read_event, path, "codex"))

    def test_grade_assertions(self) -> None:
        specs = (
            AssertionSpec("contains_all", ("Verdict", "Findings")),
            AssertionSpec("not_contains", ("LGTM",)),
            AssertionSpec("fixture_unchanged", ()),
            AssertionSpec("exit_code_zero", ()),
        )
        results = grade_assertions(
            specs,
            "Verdict\nFindings",
            0,
            {"SKILL.md": "abc"},
            {"SKILL.md": "abc"},
        )
        self.assertTrue(all(bool(result["passed"]) for result in results))

    def test_extract_total_tokens_uses_largest_completed_usage(self) -> None:
        events = "\n".join(
            (
                json.dumps({"type": "turn.completed", "usage": {"total_tokens": 120}}),
                json.dumps(
                    {
                        "type": "response.completed",
                        "usage": {"input_tokens": 100, "output_tokens": 50},
                    }
                ),
            )
        )
        self.assertEqual(extract_total_tokens(events), 150)

    def test_skill_config_disables_baseline(self) -> None:
        project = Path("/tmp/project/SKILL.md")
        override = skill_config_override(
            project, (Path("/tmp/source/SKILL.md"),), False
        )
        self.assertIn('path="/tmp/project/SKILL.md",enabled=false', override)
        self.assertIn('path="/tmp/source/SKILL.md",enabled=false', override)

    def test_help_lists_stable_commands(self) -> None:
        help_text = build_parser().format_help()
        for command in ("validate", "plan", "run", "aggregate", "check", "unit-test"):
            self.assertIn(command, help_text)

    def test_run_requires_confirmation_without_writing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            skill_dir = Path(directory) / "skill-review"
            create_test_skill(skill_dir)
            workspace = Path(directory) / "workspace"
            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                result = main(
                    [
                        "run",
                        "--skill-dir",
                        str(skill_dir),
                        "--workspace",
                        str(workspace),
                        "--attempts",
                        "1",
                    ]
                )
            self.assertEqual(result, 1)
            self.assertFalse(workspace.exists())
            self.assertIn("requires --yes", stderr.getvalue())

    def test_dry_run_does_not_write(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            skill_dir = Path(directory) / "skill-review"
            create_test_skill(skill_dir)
            workspace = Path(directory) / "workspace"
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                result = main(
                    [
                        "run",
                        "--skill-dir",
                        str(skill_dir),
                        "--workspace",
                        str(workspace),
                        "--attempts",
                        "1",
                        "--dry-run",
                    ]
                )
            self.assertEqual(result, 0)
            self.assertFalse(workspace.exists())
            self.assertIn('"total_runtime_runs": 4', stdout.getvalue())


def create_test_skill(skill_dir: Path) -> None:
    """Create a minimal valid runner fixture for inline tests."""
    (skill_dir / "evals" / "trigger").mkdir(parents=True)
    (skill_dir / "evals" / "files" / "minimal-skill").mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        "---\nname: skill-review\ndescription: Test.\n---\n", encoding="utf-8"
    )
    query_document = {
        "version": 1,
        "queries": [
            {
                "id": "query",
                "purpose": "test",
                "query": "Review {fixture}",
                "should_trigger": True,
                "fixture": "minimal-skill",
            }
        ],
    }
    write_json(skill_dir / "evals" / "trigger" / "train.json", query_document)
    validation_document = {
        "version": 1,
        "queries": [
            {
                "id": "held-out",
                "purpose": "test",
                "query": "Do something else",
                "should_trigger": False,
                "fixture": None,
            }
        ],
    }
    write_json(
        skill_dir / "evals" / "trigger" / "validation.json",
        validation_document,
    )
    write_json(
        skill_dir / "evals" / "evals.json",
        {
            "version": 1,
            "skill_name": "skill-review",
            "evals": [
                {
                    "id": "task",
                    "prompt": "Review {fixture}",
                    "expected_output": "A review.",
                    "fixture": "minimal-skill",
                    "assertions": [{"kind": "exit_code_zero", "values": []}],
                }
            ],
        },
    )


if __name__ == "__main__":
    raise SystemExit(main())
