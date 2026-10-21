#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# ///

"""Reuse detached VS Code worktree sessions and give each terminal its own shell."""

import argparse
import contextlib
import datetime as dt
import fcntl
import os
import subprocess as sp
import sys
from pathlib import Path


def workspace_prefix(directory: Path) -> str:
    result = sp.run(  # noqa: S603 - Git receives an argument vector, never shell input.
        [  # noqa: S607 - Use the user's Git.
            "git",
            "-C",
            str(directory),
            "rev-parse",
            "--show-toplevel",
            "--path-format=absolute",
            "--git-common-dir",
        ],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if result.returncode:
        return f"vscode_{directory.resolve().name}_"
    root, common = result.stdout.splitlines()
    return f"vscode_{Path(common).parent.name}-{Path(root).name}_"


def matching_sessions(prefix: str, sessions: list[str]) -> list[str]:
    candidates = []
    for name in sessions:
        if not name.startswith(prefix):
            continue
        try:
            timestamp = dt.datetime.fromisoformat(name.removeprefix(prefix))
        except ValueError:
            continue
        if timestamp.tzinfo is not None:
            candidates.append((timestamp, name))
    return [name for _, name in sorted(candidates, reverse=True)]


def reserve_detached_session(
    session: str, cache: Path | None, stack: contextlib.ExitStack
) -> bool:
    try:
        clients = sp.run(  # noqa: S603 - Session names are passed as arguments.
            ["zellij", "--session", session, "action", "list-clients"],  # noqa: S607
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except sp.TimeoutExpired:
        return False
    if clients.returncode or clients.stdout.splitlines() != [
        "CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND"
    ]:
        return False
    if cache is not None:
        lease = stack.enter_context((cache / f"{session}.lock").open("a"))
        try:
            fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", choices=("vscode", "ghostty", "alacritty"))
    parser.add_argument(
        "--new", action="store_true", help="Start a new session even in VS Code"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the selected name without starting Zellij",
    )
    args = parser.parse_args()
    prefix = workspace_prefix(Path.cwd()) if args.app == "vscode" else f"{args.app}_"
    session = None
    with contextlib.ExitStack() as stack:
        cache = (
            Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
            / "zellij-workspace"
        )
        if args.app == "vscode" and not args.dry_run:
            cache.mkdir(parents=True, exist_ok=True)
        if args.app == "vscode" and not args.new:
            result = sp.run(
                ["zellij", "list-sessions", "--short", "--no-formatting"],  # noqa: S607
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            # Zellij returns 1 when no active sessions exist.
            if result.returncode not in (0, 1):
                raise RuntimeError(
                    result.stderr.strip() or "Could not list Zellij sessions"
                )
            for candidate in matching_sessions(prefix, result.stdout.splitlines()):
                if reserve_detached_session(
                    candidate, None if args.dry_run else cache, stack
                ):
                    session = candidate
                    break
        if session is None:
            session = prefix + dt.datetime.now().astimezone().isoformat(
                timespec="microseconds"
            )
            if args.app == "vscode" and not args.dry_run:
                lease = stack.enter_context((cache / f"{session}.lock").open("a"))
                fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
                sp.run(  # noqa: S603 - The generated name is passed as one argument.
                    ["zellij", "attach", "--create-background", session],  # noqa: S607
                    check=True,
                    timeout=10,
                )
        if args.dry_run:
            print(session)
            return 0
        if args.app == "vscode":
            # Keep the lease until this client exits, including the attach startup race.
            return sp.run(  # noqa: S603 - Session names are passed as arguments.
                ["zellij", "attach", "--create", session],  # noqa: S607
                check=False,
            ).returncode
        os.execvp("zellij", ["zellij", "attach", "--create", session])  # noqa: S606, S607
    return 0


if __name__ == "__main__":
    try:
        if sys.platform == "darwin":
            # macOS TMPDIR leaves too little room for session names in Unix socket paths.
            os.environ.setdefault("ZELLIJ_SOCKET_DIR", f"/tmp/zellij-{os.getuid()}")  # noqa: S108 - Per-user socket directory, as in Zellij's default.
        sys.exit(main())
    except (OSError, RuntimeError, sp.SubprocessError) as error:
        print(f"zellij-workspace: {error}", file=sys.stderr)
        sys.exit(1)
