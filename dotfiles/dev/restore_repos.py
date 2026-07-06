#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "opentelemetry-api>=1.36.0",
#     "opentelemetry-sdk>=1.36.0",
#     "structlog>=26.1.0",
# ]
# ///

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
from pathlib import Path

import grab

DEFAULT_REPOS_FILE = Path(__file__).resolve().parent / "repos.dat"


def read_repo_urls(repos_file: Path) -> list[str]:
    seen: set[str] = set()
    urls: list[str] = []

    for line_number, raw_line in enumerate(
        repos_file.read_text().splitlines(), start=1
    ):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line in seen:
            grab.logger.warning(
                "repo_list_duplicate_skipped",
                repos_file=str(repos_file),
                line=line_number,
                repo_url=line,
            )
            continue
        seen.add(line)
        urls.append(line)

    return urls


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Restore the explicit repository list from repos.dat using the same "
            f"{grab.BARE_REPO_DIR} plus flat branch/tag worktree layout as grab.py. "
            "grab.py discovers GitHub personal and org repositories through gh; "
            "restore_repos.py restores the fixed list, including non-GitHub remotes."
        ),
    )
    parser.add_argument(
        "target_dir",
        nargs="?",
        type=Path,
        default=Path.home() / "dev",
        help="Directory to sync repositories into. Defaults to ~/dev.",
    )
    parser.add_argument(
        "--repos-file",
        type=Path,
        default=DEFAULT_REPOS_FILE,
        help=f"Repository list to restore. Defaults to {DEFAULT_REPOS_FILE}.",
    )
    parser.add_argument(
        "-j",
        "--jobs",
        type=int,
        help="Number of parallel jobs. Defaults to JOBS, otherwise min(cpu_count, 8).",
    )
    parser.add_argument(
        "--branches",
        default=",".join(grab.DEFAULT_BRANCHES),
        help=(
            "Comma-separated branch names for flat worktrees "
            "(used only when --no-all-branches is set)."
        ),
    )
    parser.add_argument(
        "--all-branches",
        action="store_true",
        default=True,
        help="Track all remote branches as flat worktrees (default: enabled).",
    )
    parser.add_argument(
        "--no-all-branches",
        action="store_false",
        dest="all_branches",
        help="Only track branches listed in --branches.",
    )
    parser.add_argument(
        "--tags",
        default="",
        help="Comma-separated tag names for detached flat worktrees.",
    )
    parser.add_argument(
        "--all-tags",
        action="store_true",
        default=True,
        help="Track all remote tags as detached flat worktrees (default: enabled).",
    )
    parser.add_argument(
        "--no-all-tags",
        action="store_false",
        dest="all_tags",
        help="Only track tags listed in --tags.",
    )
    parser.add_argument(
        "--worktrees",
        action="store_true",
        default=True,
        help="Sync flat branch and tag worktrees (default: enabled).",
    )
    parser.add_argument(
        "--no-worktrees",
        action="store_false",
        dest="worktrees",
        help="Disable worktree sync and only update worktree.git repositories.",
    )
    parser.add_argument(
        "--prune-worktrees",
        action="store_true",
        help="Remove stale flat worktrees not in target set.",
    )
    parser.add_argument(
        "--fetch-timeout",
        type=int,
        default=grab.DEFAULT_FETCH_TIMEOUT,
        help=(
            "Timeout in seconds for 'git fetch' per repository. "
            f"Default: {grab.DEFAULT_FETCH_TIMEOUT}."
        ),
    )
    return parser.parse_args()


def main() -> int:
    grab.configure_logging()
    args = parse_args()
    if not grab.require("git"):
        return 1

    repos_file = args.repos_file.expanduser()
    if not repos_file.exists():
        grab.logger.error("repo_list_missing", repos_file=str(repos_file))
        return 1

    target_dir = args.target_dir.expanduser()
    target_dir.mkdir(parents=True, exist_ok=True)
    requested_branches = None if args.all_branches else grab.parse_csv(args.branches)
    requested_tags = grab.parse_csv(args.tags)

    all_repos = read_repo_urls(repos_file)
    if not all_repos:
        grab.logger.info("no_repositories_found", repos_file=str(repos_file))
        return 0

    jobs = grab.detect_jobs(args.jobs)
    started_at = dt.datetime.now()
    grab.logger.info(
        "restore_started",
        repos_file=str(repos_file),
        target_dir=str(target_dir),
        count=len(all_repos),
        jobs=jobs,
    )

    failed: dict[str, str] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
        futures = [
            executor.submit(
                grab.clone_or_update_repo,
                repo_url,
                target_dir,
                requested_branches,
                requested_tags,
                args.all_tags,
                args.worktrees,
                args.prune_worktrees,
                args.fetch_timeout,
            )
            for repo_url in all_repos
        ]
        for future in concurrent.futures.as_completed(futures):
            try:
                repo_url, ok, reason = future.result()
            except Exception as exc:  # noqa: BLE001
                grab.logger.exception("repo_worker_failed", error=str(exc))
                return 1
            if not ok:
                failed[repo_url] = reason

    for repo_url, reason in sorted(failed.items()):
        grab.logger.error("repo_failed", repo_url=repo_url, reason=reason)

    grab.logger.info(
        "restore_complete",
        total=len(all_repos),
        failed=len(failed),
        elapsed=str(dt.datetime.now() - started_at),
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
