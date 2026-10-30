#!/usr/bin/env python3

"""Reuse detached VS Code worktree sessions and give each terminal its own shell."""

import argparse
import contextlib
import datetime as dt
import fcntl
import os
import subprocess as sp
import sys
import time
from pathlib import Path


def socket_name_budget() -> int:
    socket_root = os.environ.get("ZELLIJ_SOCKET_DIR")
    if socket_root is None:
        runtime = os.environ.get("XDG_RUNTIME_DIR") if sys.platform == "linux" else None
        socket_root = (
            str(Path(runtime) / "zellij")
            if runtime
            else str(Path(os.environ.get("TMPDIR") or "/tmp") / f"zellij-{os.getuid()}")  # noqa: S108 - Match Zellij's per-user socket root; no files are created here.
        )
    # shortcut: contract_version_1 matches Zellij 0.45; update when IPC changes.
    socket_dir = Path(socket_root) / "contract_version_1"
    return 103 - len(os.fsencode(str(socket_dir) + "/"))


def format_session_name(prefix: str, timestamp: dt.datetime, budget: int) -> str:
    app, _, label = prefix.removesuffix("_").partition("_")
    label = label.translate(str.maketrans("", "", "aeiouAEIOU"))
    compact = f"{app}_{label}_"
    local = timestamp.replace(tzinfo=None)
    seconds = local.isoformat(timespec="seconds")
    for name in (
        prefix + timestamp.isoformat(timespec="milliseconds"),
        compact + timestamp.isoformat(timespec="milliseconds"),
        compact + local.isoformat(timespec="milliseconds"),
        compact + seconds,
    ):
        if len(name.encode()) <= budget:
            return name
    label_budget = budget - len(app.encode()) - 2 - len(seconds)
    if label_budget < 1:
        raise RuntimeError(
            "Socket directory is too long; set ZELLIJ_SOCKET_DIR to a shorter path"
        )
    label = label.encode()[:label_budget].decode("utf-8", errors="ignore")
    return f"{app}_{label}_{seconds}"


def workspace_prefix(directory: Path) -> tuple[str, str]:
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
        root = directory.resolve()
        return f"vscode_{root.name}_", str(root)
    root, common = result.stdout.splitlines()
    return f"vscode_{Path(common).parent.name}-{Path(root).name}_", root


def matching_sessions(prefix: str, sessions: list[str], budget: int) -> list[str]:
    candidates = []
    for name in sessions:
        try:
            timestamp = dt.datetime.fromisoformat(name.rpartition("_")[2]).astimezone()
        except ValueError:
            continue
        if name.startswith(prefix) or name == format_session_name(
            prefix, timestamp, budget
        ):
            candidates.append((timestamp, name))
    return [name for _, name in sorted(candidates, reverse=True)]


def reserve_detached_session(
    session: str, identity: str, cache: Path, stack: contextlib.ExitStack | None
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
    path = cache / f"{session}.lock"
    if stack is None:
        try:
            owner = path.read_text()
        except FileNotFoundError:
            owner = ""
    else:
        lease = stack.enter_context(path.open("a+"))
        try:
            fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False
        lease.seek(0)
        owner = lease.read()
        if owner and owner != identity:
            lease.close()
    return not owner or owner == identity


def reserve_new_session(
    prefix: str,
    identity: str,
    budget: int,
    cache: Path | None,
    stack: contextlib.ExitStack,
) -> str:
    while True:
        session = format_session_name(prefix, dt.datetime.now().astimezone(), budget)
        if cache is None:
            return session
        try:
            lease = stack.enter_context((cache / f"{session}.lock").open("x"))
            fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
            lease.write(identity)
            lease.flush()
            return session
        except FileExistsError:
            time.sleep(0.1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "app", nargs="?", default="vscode", choices=("vscode", "ghostty", "alacritty")
    )
    parser.add_argument(
        "--new", action="store_true", help="Start a new session even in VS Code"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the selected name without starting Zellij",
    )
    args = parser.parse_args()
    prefix, identity = (
        workspace_prefix(Path.cwd())
        if args.app == "vscode"
        else (f"{args.app}_", args.app)
    )
    budget = socket_name_budget()
    session = None
    with contextlib.ExitStack() as stack:
        cache = (
            Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
            / "zellij-workspace"
        )
        if not args.dry_run:
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
            for candidate in matching_sessions(
                prefix, result.stdout.splitlines(), budget
            ):
                if reserve_detached_session(
                    candidate, identity, cache, None if args.dry_run else stack
                ):
                    session = candidate
                    break
        if session is None:
            session = reserve_new_session(
                prefix, identity, budget, None if args.dry_run else cache, stack
            )
            if args.app == "vscode" and not args.dry_run:
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
