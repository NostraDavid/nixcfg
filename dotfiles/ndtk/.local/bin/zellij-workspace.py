#!/usr/bin/env python3

"""Reuse the same Zellij session for a worktree across terminal applications."""

import argparse
import contextlib
import fcntl
import itertools
import os
import subprocess as sp
import sys
from collections.abc import Iterator
from pathlib import Path


def socket_name_budget() -> int:
    socket_root = os.environ.get("ZELLIJ_SOCKET_DIR")
    if socket_root is None:
        runtime = os.environ.get("XDG_RUNTIME_DIR") if sys.platform == "linux" else None
        socket_root = (
            str(Path(runtime) / "zellij")
            if runtime
            else str(Path(os.environ.get("TMPDIR") or "/tmp") / f"zellij-{os.getuid()}")  # noqa: S108 - Match Zellij's per-user socket root.
        )
    return 103 - len(os.fsencode(str(Path(socket_root) / "contract_version_1") + "/"))


def session_name(label: str, slot: int, budget: int) -> str:
    suffix = "" if slot == 1 else f"-{slot}"
    room = budget - len("ws_") - len(suffix)
    if len(label.encode()) > room:
        compact = label.translate(str.maketrans("", "", "aeiouAEIOU")) or label
        label = compact.encode()[: max(0, room)].decode(errors="ignore")
    if not label:
        raise RuntimeError(
            "Socket directory is too long; set ZELLIJ_SOCKET_DIR to a shorter path"
        )
    return f"ws_{label}{suffix}"


def workspace(directory: Path) -> tuple[str, str]:
    result = sp.run(  # noqa: S603
        [  # noqa: S607 - Use the Git executable from the terminal environment.
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
        return root.name or "root", str(root)
    root, common = result.stdout.splitlines()
    return f"{Path(common).parent.name}-{Path(root).name}", root


def list_sessions() -> tuple[set[str], set[str]]:
    result = sp.run(
        ["zellij", "list-sessions", "--no-formatting"],  # noqa: S607
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if (
        result.returncode == 1
        and result.stderr.strip() == "No active zellij sessions found."
    ):
        return set(), set()
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Could not list Zellij sessions")
    live, exited = set(), set()
    # --short drops the EXITED marker, so it cannot distinguish the two cases.
    for line in result.stdout.splitlines():
        name, marker, status = line.rpartition(" [Created ")
        if not marker:
            raise RuntimeError(f"Unrecognized Zellij session listing: {line}")
        (exited if status.endswith("(EXITED - attach to resurrect)") else live).add(
            name
        )
    return live, exited


def detached(name: str) -> bool:
    try:
        clients = sp.run(  # noqa: S603
            ["zellij", "--session", name, "action", "list-clients"],  # noqa: S607
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except sp.TimeoutExpired:
        return False
    return clients.returncode == 0 and clients.stdout.split() == [
        "CLIENT_ID",
        "ZELLIJ_PANE_ID",
        "RUNNING_COMMAND",
    ]


@contextlib.contextmanager
def claim(
    path: Path, identity: str, *, existing: bool, dry_run: bool, new: bool
) -> Iterator[bool]:
    try:
        if new and not dry_run:
            lock = path.open("x+")
        elif dry_run or existing:
            lock = path.open("r+")
        else:
            lock = path.open("a+")
    except FileExistsError:
        yield False
        return
    except FileNotFoundError:
        yield dry_run and not existing
        return
    with lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            yield False
            return
        lock.seek(0)
        owner = lock.read()
        if (new and dry_run) or (owner != identity and (owner or existing)):
            yield False
            return
        if not owner and not dry_run:
            lock.write(identity)
            lock.flush()
        yield True


def candidates(
    label: str, budget: int, live: set[str], exited: set[str], *, new: bool
) -> Iterator[str]:
    if not new:
        # The lease records the absolute worktree, also for older VS Code session names.
        managed = (n for n in live if n.startswith(("ws_", "vscode_")) and "/" not in n)
        yield from sorted(managed, key=lambda name: (not name.startswith("ws_"), name))
    for slot in itertools.count(1):
        name = session_name(label, slot, budget)
        if name not in live and not (new and name in exited):
            yield name


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "app", nargs="?", default="vscode", choices=("vscode", "ghostty", "alacritty")
    )
    parser.add_argument(
        "--new",
        action="store_true",
        help="Create a fresh session instead of reusing one",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the selected name without starting Zellij",
    )
    args = parser.parse_args()
    label, identity = workspace(Path.cwd())
    live, exited = list_sessions()
    cache = (
        Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
        / "zellij-workspace"
    )
    if not args.dry_run:
        cache.mkdir(parents=True, exist_ok=True)
    for name in candidates(label, socket_name_budget(), live, exited, new=args.new):
        with claim(
            cache / f"{name}.lock",
            identity,
            existing=name in live or name in exited,
            dry_run=args.dry_run,
            new=args.new,
        ) as reserved:
            if not reserved or (name in live and not detached(name)):
                continue
            if args.dry_run:
                print(name)
                return 0
            # Keep the lease through attach so concurrent terminals select different slots.
            return sp.run(  # noqa: S603 - Session name is passed as one argument.
                ["zellij", "attach", "--create", name],  # noqa: S607
                check=False,
            ).returncode
    raise AssertionError("Session slots exhausted")


if __name__ == "__main__":
    try:
        if sys.platform == "darwin":
            os.environ.setdefault("ZELLIJ_SOCKET_DIR", f"/tmp/zellij-{os.getuid()}")  # noqa: S108
        sys.exit(main())
    except (OSError, RuntimeError, sp.SubprocessError) as error:
        print(f"zellij-workspace: {error}", file=sys.stderr)
        sys.exit(1)
