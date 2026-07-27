#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# ///

"""Implement the `pde` command for opening repository worktrees in Neovim."""

from __future__ import annotations

import argparse
import os
import shlex
import shutil
import subprocess as sp
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

DEV_ROOT = Path.home() / "dev"
PROBE_TIMEOUT_SECONDS = 10


@dataclass(frozen=True)
class CliArgs:
    query: tuple[str, ...]
    dry_run: bool
    check: bool


class ReadinessError(Exception):
    """Report a missing runtime requirement."""


def find_nvim() -> str:
    executable = shutil.which("nvim")
    if executable is None:
        raise ReadinessError(
            "Neovim executable not found; install nvim in the user profile."
        )
    return executable


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


def is_path_argument(argument: str) -> bool:
    if not argument or argument.startswith("-"):
        return False

    path = Path(argument).expanduser()
    return (
        path.exists()
        or argument in {".", "..", "~"}
        or argument.startswith(("./", "../", "~/", "/"))
        or "/" in argument
    )


def normalize_argument(argument: str) -> str:
    if not is_path_argument(argument):
        return argument
    return str(Path(argument).expanduser().resolve(strict=False))


def resolve_direct_arguments(arguments: Sequence[str]) -> list[str] | None:
    if not arguments:
        return None
    if any(
        argument.startswith("-") or is_path_argument(argument) for argument in arguments
    ):
        return [normalize_argument(argument) for argument in arguments]
    return None


def parse_args(argv: list[str] | None = None) -> CliArgs:
    raw_args = sys.argv[1:] if argv is None else argv
    if raw_args == ["check"]:
        return CliArgs(query=(), dry_run=False, check=True)

    parser = argparse.ArgumentParser(
        description="Open a repository worktree in the Neovim PDE.",
        epilog="commands:\n  check     Verify runtime readiness and print exactly 'ok'.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Resolve and validate the target without changing worktrees or starting Neovim.",
    )
    parser.add_argument(
        "query", nargs="*", help="Initial fzf query for the repository."
    )
    parsed = parser.parse_args(raw_args)
    return CliArgs(
        query=tuple(parsed.query),
        dry_run=bool(parsed.dry_run),
        check=False,
    )


def probe(
    command: list[str],
    *,
    failure_name: str,
) -> str | None:
    try:
        result = sp.run(
            command,
            check=False,
            text=True,
            stdout=sp.PIPE,
            stderr=sp.PIPE,
            timeout=PROBE_TIMEOUT_SECONDS,
        )
    except sp.TimeoutExpired:
        return f"{failure_name} readiness probe timed out."

    if result.returncode == 0:
        return None
    diagnostic = (result.stderr or result.stdout).strip()
    suffix = f": {diagnostic}" if diagnostic else "."
    return f"{failure_name} readiness probe failed{suffix}"


def readiness_errors() -> list[str]:
    errors: list[str] = []
    try:
        nvim = find_nvim()
    except ReadinessError as error:
        errors.append(str(error))
    else:
        if error := probe([nvim, "--version"], failure_name="Neovim"):
            errors.append(error)

    try:
        picker = find_project_picker()
    except ReadinessError as error:
        errors.append(str(error))
    else:
        if error := probe([picker, "--help"], failure_name="project_picker"):
            errors.append(error)

    for executable in ("fzf", "git"):
        if shutil.which(executable) is None:
            errors.append(f"{executable} executable not found in PATH.")

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


def preview(command: list[str]) -> int:
    print(f"Would run: {shlex.join(command)}")
    return 0


def launch(command: list[str]) -> int:
    """Run interactive Neovim without a timeout so editing is not interrupted."""
    return sp.run(command, check=False).returncode


def select_worktree(query: Sequence[str], *, dry_run: bool) -> Path | None:
    try:
        picker = find_project_picker()
    except ReadinessError as error:
        print(error, file=sys.stderr)
        return None

    command = [picker]
    if dry_run:
        command.append("--dry-run")
    command.extend(query)

    # Repository and worktree selection is interactive and intentionally unbounded.
    result = sp.run(
        command,
        check=False,
        text=True,
        stdout=sp.PIPE,
        stderr=sp.PIPE,
    )
    if result.returncode != 0:
        print(result.stderr, end="", file=sys.stderr)
        return None
    return Path(result.stdout.strip())


def main() -> int:
    args = parse_args()
    if args.check:
        return run_check()

    try:
        nvim = find_nvim()
    except ReadinessError as error:
        print(error, file=sys.stderr)
        return 1

    direct_arguments = resolve_direct_arguments(args.query)
    if direct_arguments is not None:
        command = [nvim, *direct_arguments]
    elif args.query:
        target = select_worktree(args.query, dry_run=args.dry_run)
        if target is None:
            return 1
        command = [nvim, str(target)]
    else:
        command = [nvim]

    if args.dry_run:
        return preview(command)
    return launch(command)


if __name__ == "__main__":
    raise SystemExit(main())
