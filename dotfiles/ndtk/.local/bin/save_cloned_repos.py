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
import tempfile
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import structlog as sl
from structlog.stdlib import get_logger

REMOTE_URL_RE = re.compile(r"^(?:(?:https?|ssh|git|file)://|[^@\s]+@[^:\s]+:)")
DEFAULT_REPOS_FILE = (
    Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    / "ndtk/repos.dat"
)
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
    result = subprocess.run(
        [
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


def without_credentials(url: str) -> str:
    if "://" not in url:
        return url
    parts = urlsplit(url)
    hostname = parts.hostname
    if hostname is None:
        return url
    host = f"[{hostname}]" if ":" in hostname else hostname
    netloc = f"{host}:{parts.port}" if parts.port is not None else host
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


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
        default=DEFAULT_REPOS_FILE,
        help=f"File to write repository URLs to. Defaults to {DEFAULT_REPOS_FILE}.",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print URLs without writing."
    )
    return parser.parse_args()


def main() -> int:
    configure_logging()
    args = parse_args()
    search_dir = args.search_dir.expanduser()
    repos_file = args.repos_file.expanduser()

    if not search_dir.is_dir():
        logger.error("directory_not_found", path=str(search_dir))
        return 1

    logger.info("scan_started", path=str(search_dir))

    urls = {
        without_credentials(url)
        for gitdir in git_markers(search_dir)
        if (url := origin_url(gitdir.parent)) and REMOTE_URL_RE.search(url)
    }

    content = "".join(f"{url}\n" for url in sorted(urls, key=str.casefold))
    if args.dry_run:
        print(content, end="")
        return 0
    repos_file.parent.mkdir(parents=True, exist_ok=True)
    try:
        atomic_write(repos_file, content)
    except OSError as error:
        logger.error("repo_list_write_failed", path=str(repos_file), reason=str(error))
        return 1

    count = len(urls)
    logger.info("repos_saved", count=count, path=str(repos_file))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
