#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///

"""Fetch every existing git repository under a local project tree.

Use `grab.py` when you want to discover GitHub personal and organization repos
via `gh` and clone/pull them. Use this script when repos already exist locally
and you only want to refresh their remotes with `git fetch`.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import logging
import os
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

DEFAULT_PROJECT = Path("~/dev").expanduser()

logger = logging.getLogger("update_local_repos")


class JSONFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        ts = dt.datetime.fromtimestamp(record.created, dt.timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        payload: dict[str, object] = {
            "ts": ts,
            "level": record.levelname.lower(),
            "event": getattr(record, "event", record.getMessage()),
        }
        data = getattr(record, "extra", None)
        if isinstance(data, dict):
            payload.update(data)
        return json.dumps(payload, separators=(",", ":"))


def configure_logging(level_name: str) -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JSONFormatter())
    logger.handlers[:] = [handler]
    logger.setLevel(getattr(logging, level_name.upper(), logging.INFO))
    logger.propagate = False


def git_repos(root: Path) -> list[Path]:
    repos: list[Path] = []
    for current, dirs, files in os.walk(root):
        current_path = Path(current)
        if ".git" in dirs:
            repos.append(current_path)
            dirs.remove(".git")
        elif ".git" in files:
            repos.append(current_path)

        dirs[:] = [
            dirname
            for dirname in dirs
            if dirname
            not in {
                ".cache",
                ".direnv",
                ".mypy_cache",
                ".pytest_cache",
                ".ruff_cache",
                ".tox",
                ".trash",
                ".venv",
                "__pycache__",
                "node_modules",
                "target",
            }
        ]
    return sorted(set(repos))


def run_fetch(repo: Path, dry_run: bool) -> tuple[Path, bool, bool, float, str]:
    start = time.perf_counter()
    args = ["git", "-C", str(repo), "fetch", "--all", "--prune"]
    if dry_run:
        args.append("--dry-run")
    proc = subprocess.run(
        args,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    output = proc.stdout or ""
    updated = bool(output.strip()) and proc.returncode == 0
    duration = round(time.perf_counter() - start, 3)
    return repo, proc.returncode == 0, updated, duration, output[-2000:]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Fetch existing local git repositories. This does not discover or "
            "clone GitHub repos; use grab.py for that workflow."
        )
    )
    parser.add_argument(
        "root",
        nargs="?",
        type=Path,
        default=DEFAULT_PROJECT,
        help="Directory to scan for git repositories (default: ~/dev).",
    )
    parser.add_argument(
        "-j",
        "--jobs",
        type=int,
        default=min(os.cpu_count() or 4, 8),
        help="Number of parallel fetches (default: min(cpu_count, 8)).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run git fetch --dry-run without updating remotes.",
    )
    parser.add_argument(
        "--log-level",
        default=os.environ.get("UPDATE_REPOS_LOGLEVEL", "INFO"),
        help="Python logging level (default: UPDATE_REPOS_LOGLEVEL or INFO).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    configure_logging(args.log_level)
    root = args.root.expanduser()

    if not root.is_dir():
        logger.error(
            "root_not_found",
            extra={"event": "root_not_found", "extra": {"root": str(root)}},
        )
        return 1

    repos = git_repos(root)
    logger.info(
        "start",
        extra={
            "event": "start",
            "extra": {"root": str(root), "repos": len(repos), "jobs": args.jobs},
        },
    )
    if not repos:
        return 0

    failures = 0
    updated = 0
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
        futures = [executor.submit(run_fetch, repo, args.dry_run) for repo in repos]
        for future in as_completed(futures):
            repo, ok, changed, duration, output = future.result()
            if ok:
                if changed:
                    updated += 1
                logger.info(
                    "fetch_result",
                    extra={
                        "event": "fetch_result",
                        "extra": {
                            "repo": str(repo),
                            "updated": changed,
                            "dur_s": duration,
                        },
                    },
                )
            else:
                failures += 1
                logger.warning(
                    "fetch_error",
                    extra={
                        "event": "fetch_error",
                        "extra": {
                            "repo": str(repo),
                            "dur_s": duration,
                            "output": output,
                        },
                    },
                )

    logger.info(
        "done",
        extra={
            "event": "done",
            "extra": {"repos": len(repos), "updated": updated, "failed": failures},
        },
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
