#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "structlog>=26.1.0",
# ]
# ///

import argparse
import os
import subprocess
import sys
from pathlib import Path

import structlog as sl
from structlog.stdlib import get_logger

logger = get_logger()


def configure_logging() -> None:
    sl.configure(
        processors=[
            sl.processors.TimeStamper(fmt="iso"),
            sl.processors.add_log_level,
            sl.dev.ConsoleRenderer(colors=sys.stderr.isatty()),
        ],
    )


def run_git(
    repo_path: Path, args: list[str], *, capture: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(  # noqa: S603 - arguments are constructed by this tool
        ["git", *args],  # noqa: S607 - Git is intentionally resolved from PATH
        cwd=repo_path,
        check=False,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def git_dirs(search_dir: Path) -> list[Path]:
    result: list[Path] = []
    for root, dirs, _files in os.walk(search_dir):
        if ".git" in dirs:
            result.append(Path(root) / ".git")
            dirs.remove(".git")
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Find git repositories with uncommitted or unpushed changes.",
    )
    parser.add_argument(
        "search_dir",
        nargs="?",
        type=Path,
        default=Path.home() / "dev",
        help="Directory to scan for git repositories. Defaults to ~/dev.",
    )
    return parser.parse_args()


def main() -> int:
    configure_logging()
    args = parse_args()
    search_dir = args.search_dir.expanduser()

    if not search_dir.is_dir():
        logger.error("directory_not_found", path=str(search_dir))
        return 1

    logger.info("search_started", path=str(search_dir))

    for gitdir in git_dirs(search_dir):
        repo_path = gitdir.parent

        diff = run_git(repo_path, ["diff", "--quiet", "--ignore-submodules", "HEAD"])
        if diff.returncode != 0:
            logger.warning("repo_has_uncommitted_changes", repo=str(repo_path))
            run_git(repo_path, ["status", "-s"])
            continue

        unpushed = run_git(repo_path, ["log", "@{u}.."], capture=True)
        if unpushed.returncode == 0 and unpushed.stdout:
            logger.warning("repo_has_unpushed_commits", repo=str(repo_path))
            run_git(repo_path, ["status", "-sb"])

    logger.info("search_complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
