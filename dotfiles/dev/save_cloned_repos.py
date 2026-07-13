#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "structlog>=26.1.0",
# ]
# ///

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

import structlog as sl
from structlog.stdlib import get_logger

REMOTE_URL_RE = re.compile(r"^(?:(?:https?|ssh|git|file)://|[^@\s]+@[^:\s]+:)")
logger = get_logger()


def configure_logging() -> None:
    sl.configure(
        processors=[
            sl.processors.TimeStamper(fmt="iso"),
            sl.processors.add_log_level,
            sl.dev.ConsoleRenderer(colors=sys.stderr.isatty()),
        ],
    )


def git_markers(search_dir: Path) -> list[Path]:
    result: list[Path] = []
    for root, dirs, files in os.walk(search_dir):
        if ".git" in dirs:
            result.append(Path(root) / ".git")
            dirs.remove(".git")
        if ".git" in files:
            result.append(Path(root) / ".git")
    return result


def origin_url(repo_path: Path) -> str:
    result = subprocess.run(  # noqa: S603 - arguments are constructed by this tool
        [  # noqa: S607 - Git is intentionally resolved from PATH
            "git",
            "-C",
            str(repo_path),
            "remote",
            "get-url",
            "origin",
        ],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Save origin URLs for git repositories found under a directory.",
    )
    parser.add_argument(
        "search_dir",
        nargs="?",
        type=Path,
        default=Path.home() / "dev",
        help="Directory to scan for git repositories. Defaults to ~/dev.",
    )
    parser.add_argument(
        "repos_file",
        nargs="?",
        type=Path,
        help="File to write repository URLs to. Defaults to SEARCH_DIR/repos.dat.",
    )
    return parser.parse_args()


def main() -> int:
    configure_logging()
    args = parse_args()
    search_dir = args.search_dir.expanduser()
    repos_file = (
        args.repos_file.expanduser() if args.repos_file else search_dir / "repos.dat"
    )

    if not search_dir.is_dir():
        logger.error("directory_not_found", path=str(search_dir))
        return 1

    repos_file.parent.mkdir(parents=True, exist_ok=True)

    logger.info("scan_started", path=str(search_dir))

    urls = {
        url
        for gitdir in git_markers(search_dir)
        if (url := origin_url(gitdir.parent)) and REMOTE_URL_RE.search(url)
    }

    repos_file.write_text("".join(f"{url}\n" for url in sorted(urls, key=str.casefold)))

    count = len(urls)
    logger.info("repos_saved", count=count, path=str(repos_file))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
