#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# ///

"""Implement the `ide` command for opening repository worktrees in VS Code."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess as sp
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

WINDOW_FLAGS = {"--new-window", "--reuse-window", "--add", "-r"}
DEV_ROOT = Path.home() / "dev"
CLI_PROBE_TIMEOUT_SECONDS = 10
CLI_LAUNCH_TIMEOUT_SECONDS = 30


@dataclass(frozen=True)
class CliArgs:
    query: tuple[str, ...]
    dry_run: bool
    check: bool
    no_picker: bool


class ReadinessError(Exception):
    """Report a missing runtime requirement."""


def run(args: list[str]) -> sp.CompletedProcess[str]:
    """Run the interactive picker, which intentionally has no timeout."""
    return sp.run(
        args,
        check=False,
        text=True,
        stdout=sp.PIPE,
        stderr=sp.PIPE,
    )


def require(command: str) -> None:
    if shutil.which(command) is None:
        print(f"{command} executable not found.", file=sys.stderr)
        raise SystemExit(1)


def find_code_command() -> list[str]:
    own_path = Path(__file__).resolve()
    for path_dir in os.environ.get("PATH", "").split(os.pathsep):
        if not path_dir:
            continue

        candidate = Path(path_dir) / "code"
        if not candidate.exists() or not os.access(candidate, os.X_OK):
            continue
        if candidate.resolve() == own_path:
            continue

        package_root = candidate.resolve().parent.parent
        electron = package_root / "lib/vscode/code"
        cli = package_root / "lib/vscode/resources/app/out/cli.js"
        if (
            electron.is_file()
            and os.access(electron, os.X_OK)
            and cli.is_file()
            and os.access(cli, os.R_OK)
        ):
            return [str(electron), str(cli)]

    raise ReadinessError(
        "VS Code CLI executable not found; install VS Code in the user profile."
    )


def find_project_picker() -> str:
    adjacent = Path(__file__).resolve().with_name("project_picker.py")
    if adjacent.exists() and os.access(adjacent, os.X_OK):
        return str(adjacent)

    picker = shutil.which("project_picker")
    if picker is not None:
        return picker

    raise ReadinessError(
        "project_picker executable not found; activate the Home Manager configuration."
    )


def clean_vscode_env() -> dict[str, str]:
    env = os.environ.copy()
    for name in tuple(env):
        if name.startswith("VSCODE_"):
            env.pop(name)

    for name in (
        "ELECTRON_RUN_AS_NODE",
        "VIRTUAL_ENV",
        "UV_RUN_RECURSION_DEPTH",
        "NIX_CONFIG",
        "IN_NIX_SHELL",
        "shellHook",
        "stdenv",
        "out",
        "buildInputs",
        "nativeBuildInputs",
        "builder",
        "phases",
    ):
        env.pop(name, None)
    env["ELECTRON_RUN_AS_NODE"] = "1"
    return env


def is_path_argument(arg: str) -> bool:
    if not arg or arg.startswith("-"):
        return False

    path = Path(arg).expanduser()
    return (
        path.exists()
        or arg in {".", "..", "~"}
        or arg.startswith(("./", "../", "~/", "/"))
        or "/" in arg
    )


def normalize_code_arg(arg: str) -> str:
    if not is_path_argument(arg):
        return arg

    return str(Path(arg).expanduser().resolve(strict=False))


def resolve_direct_code_args(args: Sequence[str]) -> list[str] | None:
    if not args:
        return None

    if any(arg.startswith("-") or is_path_argument(arg) for arg in args):
        return [normalize_code_arg(arg) for arg in args]

    return None


def add_new_window_flag(
    command: list[str],
    *,
    argument_start: int,
    skip_when_flags_present: bool = False,
) -> list[str]:
    arguments = command[argument_start:]
    if skip_when_flags_present and any(arg.startswith("-") for arg in arguments):
        return command

    if any(arg in WINDOW_FLAGS for arg in arguments):
        return command

    return [*command[:argument_start], "--new-window", *arguments]


def plan_vscode_settings(target: Path) -> tuple[Path, dict[str, object]] | None:
    """Plan a settings write when the project title is absent or incorrect.

    The project name is the parent folder name (e.g. for ~/dev/org/repo/trunk,
    the project name is "repo").
    """
    settings_file = target / ".vscode" / "settings.json"
    project_name = target.parent.name

    if not settings_file.exists():
        return settings_file, {"window.title": project_name}

    try:
        settings = json.loads(settings_file.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None
    if not isinstance(settings, dict):
        return None

    if settings.get("window.title") == project_name:
        return None

    settings["window.title"] = project_name
    return settings_file, settings


def ensure_vscode_settings(target: Path) -> None:
    plan = plan_vscode_settings(target)
    if plan is None:
        return

    settings_file, settings = plan
    settings_file.parent.mkdir(parents=True, exist_ok=True)
    settings_file.write_text(
        json.dumps(settings, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def parse_args(argv: list[str] | None = None) -> CliArgs:
    raw_args = sys.argv[1:] if argv is None else argv
    if raw_args == ["check"]:
        return CliArgs(query=(), dry_run=False, check=True, no_picker=False)

    parser = argparse.ArgumentParser(
        description="Open a repository worktree in VS Code.",
        epilog="commands:\n  check     Verify runtime readiness and print exactly 'ok'.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Resolve and validate the target without writing files or opening VS Code.",
    )
    parser.add_argument(
        "--no-picker",
        action="store_true",
        help="Bypass project selection and pass paths directly to VS Code.",
    )
    parser.add_argument("query", nargs="*", help="Initial fzf query for the repo.")
    parsed = parser.parse_args(raw_args)
    return CliArgs(
        query=tuple(parsed.query),
        dry_run=bool(parsed.dry_run),
        check=False,
        no_picker=bool(parsed.no_picker),
    )


def readiness_errors() -> list[str]:
    errors: list[str] = []
    try:
        code_command = find_code_command()
    except ReadinessError as error:
        errors.append(str(error))
    else:
        try:
            probe = sp.run(
                [*code_command, "--version"],
                check=False,
                env=clean_vscode_env(),
                text=True,
                stdout=sp.PIPE,
                stderr=sp.PIPE,
                timeout=CLI_PROBE_TIMEOUT_SECONDS,
            )
        except sp.TimeoutExpired:
            errors.append("VS Code CLI readiness probe timed out.")
        else:
            if probe.returncode != 0:
                diagnostic = (probe.stderr or probe.stdout).strip()
                suffix = f": {diagnostic}" if diagnostic else "."
                errors.append(f"VS Code CLI readiness probe failed{suffix}")

    try:
        picker = find_project_picker()
    except ReadinessError as error:
        errors.append(str(error))
    else:
        try:
            probe = sp.run(
                [picker, "--help"],
                check=False,
                text=True,
                stdout=sp.PIPE,
                stderr=sp.PIPE,
                timeout=CLI_PROBE_TIMEOUT_SECONDS,
            )
        except sp.TimeoutExpired:
            errors.append("project_picker readiness probe timed out.")
        else:
            if probe.returncode != 0:
                diagnostic = (probe.stderr or probe.stdout).strip()
                suffix = f": {diagnostic}" if diagnostic else "."
                errors.append(f"project_picker readiness probe failed{suffix}")

    for command in ("fzf", "git"):
        if shutil.which(command) is None:
            errors.append(f"{command} executable not found in PATH.")

    if not DEV_ROOT.is_dir():
        errors.append(f"Development directory not found: {DEV_ROOT}")
    elif not os.access(DEV_ROOT, os.R_OK | os.X_OK):
        errors.append(f"Development directory is not readable: {DEV_ROOT}")

    return errors


def run_check() -> int:
    errors = readiness_errors()
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("ok")
    return 0


def preview(
    command: list[str],
    *,
    settings_plan: tuple[Path, dict[str, object]] | None = None,
) -> int:
    if settings_plan is not None:
        print(f"Would write VS Code settings: {settings_plan[0]}")
    print(f"Would run: {shlex.join(command)}")
    return 0


def launch_code(command: list[str], env: dict[str, str]) -> int:
    try:
        return sp.run(
            command,
            env=env,
            check=False,
            timeout=CLI_LAUNCH_TIMEOUT_SECONDS,
        ).returncode
    except sp.TimeoutExpired:
        print(
            f"VS Code CLI did not respond within {CLI_LAUNCH_TIMEOUT_SECONDS} seconds.",
            file=sys.stderr,
        )
        return 1


def main() -> int:
    args = parse_args()
    if args.check:
        return run_check()

    try:
        code_command = find_code_command()
    except ReadinessError as error:
        print(error, file=sys.stderr)
        return 1
    env = clean_vscode_env()

    if args.no_picker:
        direct_args = [normalize_code_arg(arg) for arg in args.query]
        command = [*code_command, *direct_args]
        if direct_args:
            command = add_new_window_flag(
                command,
                argument_start=len(code_command),
            )
        if args.dry_run:
            return preview(command)
        return launch_code(command, env)

    direct_args = resolve_direct_code_args(args.query)
    if direct_args is not None:
        command = add_new_window_flag(
            [*code_command, *direct_args],
            argument_start=len(code_command),
            skip_when_flags_present=True,
        )
        if args.dry_run:
            return preview(command)
        return launch_code(command, env)

    try:
        picker = find_project_picker()
    except ReadinessError as error:
        print(error, file=sys.stderr)
        return 1
    picker_args = [picker]
    if args.dry_run:
        picker_args.append("--dry-run")
    picker_args.extend(args.query)
    proc = run(picker_args)
    if proc.returncode != 0:
        print(proc.stderr, end="", file=sys.stderr)
        return proc.returncode

    target = Path(proc.stdout.strip())
    command = add_new_window_flag(
        [*code_command, str(target)],
        argument_start=len(code_command),
    )
    if args.dry_run:
        return preview(command, settings_plan=plan_vscode_settings(target))

    ensure_vscode_settings(target)
    return launch_code(command, env)


if __name__ == "__main__":
    raise SystemExit(main())
