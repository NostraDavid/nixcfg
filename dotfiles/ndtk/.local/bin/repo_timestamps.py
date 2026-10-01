#!/usr/bin/env python3
"""Align repository file and directory mtimes with local Git history."""

from __future__ import annotations

import os
import subprocess
import sys
from argparse import ArgumentParser
from dataclasses import dataclass
from pathlib import Path

WORKTREE_GIT_DIR_NAME = "worktree.git"
GIT_METADATA_NAMES = {".git", WORKTREE_GIT_DIR_NAME}
DPRINT_CONFIG_NAME = "dprint.jsonc"


def ensure_dprint_config_link(repo_path: Path) -> bool:
    config_dir = Path(
        os.environ.get("DPRINT_CONFIG_DIR", str(Path.home() / ".config" / "dprint"))
    )
    source = config_dir / DPRINT_CONFIG_NAME
    destination = repo_path / DPRINT_CONFIG_NAME
    if not source.is_file() or destination.exists() or destination.is_symlink():
        return False
    if _run_git(repo_path, ["check-ignore", "-q", DPRINT_CONFIG_NAME]).returncode != 0:
        return False
    try:
        destination.symlink_to(source)
    except OSError:
        return False
    return True


@dataclass(frozen=True, slots=True)
class RefreshStats:
    files_updated: int = 0
    directories_updated: int = 0
    worktrees_scanned: int = 0


def _run_git(repo_path: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(  # noqa: S603
        ["git", "-C", str(repo_path), *args],  # noqa: S607
        check=False,
        capture_output=True,
        text=True,
    )


def _worktree_paths(bare_dir: Path) -> list[Path]:
    proc = _run_git(bare_dir, ["worktree", "list", "--porcelain"])
    if proc.returncode != 0:
        return []
    return [
        Path(line.removeprefix("worktree "))
        for line in (proc.stdout or "").splitlines()
        if line.startswith("worktree ")
    ]


def _latest_file_times(worktree: Path) -> dict[Path, int]:
    dirty_proc = _run_git(
        worktree, ["diff", "--no-renames", "--name-only", "HEAD", "--"]
    )
    dirty_paths = {
        Path(line) for line in (dirty_proc.stdout or "").splitlines() if line
    }
    proc = _run_git(
        worktree,
        [
            "log",
            "--format=commit:%ct",
            "--name-only",
            "--no-renames",
            "HEAD",
            "--",
        ],
    )
    if proc.returncode != 0:
        return {}

    latest: dict[Path, int] = {}
    commit_time: int | None = None
    for line in (proc.stdout or "").splitlines():
        if line.startswith("commit:"):
            try:
                commit_time = int(line.removeprefix("commit:"))
            except ValueError:
                commit_time = None
        elif line and commit_time is not None:
            path = Path(line)
            if path not in dirty_paths:
                latest.setdefault(path, commit_time)
    return latest


def _visible_worktree_paths(worktree: Path) -> tuple[set[Path], set[Path]]:
    proc = _run_git(
        worktree,
        ["ls-files", "--cached", "--others", "--exclude-standard", "-z"],
    )
    if proc.returncode != 0:
        return set(), {worktree}

    files = {
        worktree / Path(raw_path)
        for raw_path in (proc.stdout or "").split("\0")
        if raw_path
    }
    directories = {worktree}
    for path in files:
        relative_path = path.relative_to(worktree)
        directories.update(
            worktree / parent for parent in relative_path.parents if parent.parts
        )
    return files, directories


def _set_mtime_ns(path: Path, timestamp_ns: int) -> bool:
    try:
        os.utime(path, ns=(timestamp_ns, timestamp_ns), follow_symlinks=False)
    except OSError:
        return False
    return True


def _set_mtime(path: Path, timestamp: int) -> bool:
    return _set_mtime_ns(path, timestamp * 1_000_000_000)


def _refresh_worktree_files(
    worktree: Path,
    visible_files: set[Path],
    visible_directories: set[Path],
) -> int:
    latest_file_times = _latest_file_times(worktree)
    updated = 0
    for current, directories, files in os.walk(
        worktree, topdown=True, followlinks=False
    ):
        directories[:] = [
            name
            for name in directories
            if name not in GIT_METADATA_NAMES
            and Path(current) / name in visible_directories
        ]
        for name in files:
            if name in GIT_METADATA_NAMES:
                continue
            path = Path(current) / name
            if path not in visible_files:
                continue
            timestamp = latest_file_times.get(path.relative_to(worktree))
            if timestamp is not None and _set_mtime(path, timestamp):
                updated += 1
    return updated


def _refresh_directory_mtimes(
    repo_root: Path,
    visible_files: set[Path],
    visible_directories: set[Path],
) -> int:
    entries_by_directory: list[tuple[Path, list[Path]]] = []
    for current, directories, files in os.walk(
        repo_root, topdown=True, followlinks=False
    ):
        directories[:] = [
            name
            for name in directories
            if name not in GIT_METADATA_NAMES
            and Path(current) / name in visible_directories
            and not (Path(current) / name).is_symlink()
        ]
        files[:] = [
            name
            for name in files
            if name not in GIT_METADATA_NAMES
            and Path(current) / name in visible_files
            and not (Path(current) / name).is_symlink()
        ]
        entries_by_directory.append(
            (
                Path(current),
                [Path(current) / name for name in (*directories, *files)],
            )
        )

    updated = 0
    for directory, entries in reversed(entries_by_directory):
        child_mtimes: list[int] = []
        for entry in entries:
            try:
                child_mtimes.append(entry.stat(follow_symlinks=False).st_mtime_ns)
            except OSError:
                continue
        if child_mtimes and _set_mtime_ns(directory, max(child_mtimes)):
            updated += 1
    return updated


def refresh_repository_tree(
    repo_path: Path, *, bare_dir: Path | None = None
) -> RefreshStats:
    """Set tracked files to commit time, then propagate mtimes up the tree."""
    if bare_dir is None:
        candidate = repo_path / WORKTREE_GIT_DIR_NAME
        if candidate.is_dir():
            repo_root = repo_path
            bare_dir = candidate
        else:
            candidate = repo_path.parent / WORKTREE_GIT_DIR_NAME
        if candidate.is_dir() and bare_dir is None:
            repo_root = repo_path.parent
            bare_dir = candidate
        elif bare_dir is None:
            repo_root = repo_path
    else:
        repo_root = repo_path

    if not repo_root.is_dir():
        return RefreshStats()

    worktrees = (
        [
            path
            for path in _worktree_paths(bare_dir)
            if path != bare_dir and path.is_dir() and path.is_relative_to(repo_root)
        ]
        if bare_dir is not None and bare_dir.is_dir()
        else [repo_root]
    )
    visible_files: set[Path] = set()
    visible_directories: set[Path] = set()
    files_updated = 0
    for worktree in worktrees:
        worktree_files, worktree_directories = _visible_worktree_paths(worktree)
        visible_files.update(worktree_files)
        visible_directories.update(worktree_directories)
        files_updated += _refresh_worktree_files(
            worktree, worktree_files, worktree_directories
        )
    directories_updated = _refresh_directory_mtimes(
        repo_root, visible_files, visible_directories
    )
    return RefreshStats(
        files_updated=files_updated,
        directories_updated=directories_updated,
        worktrees_scanned=len(worktrees),
    )


def _repository_roots(search_root: Path) -> list[Path]:
    roots: set[Path] = set()
    for current, directories, files in os.walk(
        search_root, topdown=True, followlinks=False
    ):
        current_path = Path(current)
        kept_directories: list[str] = []
        for name in directories:
            if name == WORKTREE_GIT_DIR_NAME or name == ".git":
                roots.add(current_path)
            else:
                kept_directories.append(name)
        directories[:] = kept_directories

        if (
            ".git" in files
            and not (current_path.parent / WORKTREE_GIT_DIR_NAME).is_dir()
        ):
            roots.add(current_path)
    return sorted(roots, key=lambda path: str(path).casefold())


def main(argv: list[str] | None = None) -> int:
    parser = ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        action="append",
        required=True,
        type=Path,
        help="Directory tree containing repositories; may be repeated.",
    )
    args = parser.parse_args(argv)

    total = RefreshStats()
    repository_count = 0
    for search_root in args.root:
        for repo_root in _repository_roots(search_root.expanduser()):
            stats = refresh_repository_tree(repo_root)
            repository_count += 1
            total = RefreshStats(
                files_updated=total.files_updated + stats.files_updated,
                directories_updated=total.directories_updated
                + stats.directories_updated,
                worktrees_scanned=total.worktrees_scanned + stats.worktrees_scanned,
            )
            print(
                f"{repo_root}: files={stats.files_updated} directories={stats.directories_updated} worktrees={stats.worktrees_scanned}"
            )

    print(
        f"repositories={repository_count} files={total.files_updated} directories={total.directories_updated} worktrees={total.worktrees_scanned}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
