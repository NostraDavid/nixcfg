#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "structlog>=26.1.0",
# ]
# ///

import argparse
import concurrent.futures
import json
import os
import shutil
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


def require(command: str) -> bool:
    if shutil.which(command):
        return True
    logger.error("command_not_found", command=command)
    return False


def run(
    args: list[str],
    *,
    cwd: Path | None = None,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE if capture else None,
    )


def gh_text(args: list[str]) -> str:
    result = run(["gh", *args], capture=True)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
    return result.stdout.strip()


def gh_json(args: list[str]) -> object:
    output = gh_text(args)
    return json.loads(output) if output else None


def detect_jobs(jobs: int | None = None) -> int:
    if jobs is not None:
        return jobs
    env_jobs = os.environ.get("JOBS")
    if env_jobs:
        return int(env_jobs)
    cpus = os.cpu_count() or 4
    return min(cpus, 8)


def repo_path_part(repo_url: str) -> str:
    if repo_url.startswith("git@github.com:"):
        repo_url = repo_url.removeprefix("git@github.com:")
    if repo_url.endswith(".git"):
        repo_url = repo_url[:-4]
    return repo_url


def clone_or_pull(repo_url: str, target_dir: Path) -> tuple[str, bool]:
    org_and_repo = repo_path_part(repo_url)
    target_path = target_dir / org_and_repo
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if target_path.is_dir():
        logger.info("pulling_repo", repo=org_and_repo)
        result = run(["git", "pull"], cwd=target_path)
    else:
        logger.info("cloning_repo", repo=org_and_repo)
        result = run(["git", "clone", repo_url, str(target_path)])

    return repo_url, result.returncode == 0


def repo_urls(owner: str) -> list[str]:
    repos = gh_json(["repo", "list", owner, "--limit", "1000", "--json", "sshUrl"])
    if not isinstance(repos, list):
        return []

    urls: list[str] = []
    for repo in repos:
        if not isinstance(repo, dict):
            continue
        url = repo.get("sshUrl")
        if isinstance(url, str):
            urls.append(url)
    return urls


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Clone or pull all personal and organization GitHub repositories.",
    )
    parser.add_argument(
        "target_dir",
        nargs="?",
        type=Path,
        default=Path.home() / "dev",
        help="Directory to clone repositories into. Defaults to ~/dev.",
    )
    parser.add_argument(
        "-j",
        "--jobs",
        type=int,
        help="Number of parallel jobs. Defaults to JOBS, otherwise min(cpu_count, 8).",
    )
    return parser.parse_args()


def main() -> int:
    configure_logging()
    args = parse_args()
    if not require("gh"):
        return 1

    target_dir = args.target_dir.expanduser()
    target_dir.mkdir(parents=True, exist_ok=True)

    jobs = detect_jobs(args.jobs)
    logger.info("sync_started", target_dir=str(target_dir), jobs=jobs)

    user = gh_text(["api", "user", "--jq", ".login"])

    logger.info("gathering_personal_repos", user=user)
    personal_repos = repo_urls(user)

    logger.info("gathering_organization_repos")
    org_repos: list[str] = []
    orgs = gh_text(["api", "user/orgs", "--jq", ".[].login"]).splitlines()
    for org in orgs:
        logger.info("gathering_org_repos", org=org)
        org_repos.extend(repo_urls(org))

    all_repos = personal_repos + org_repos

    if not all_repos:
        logger.info("no_repositories_found")
        return 0

    logger.info("processing_repositories", count=len(all_repos), jobs=jobs)

    failed: set[str] = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
        futures = [
            executor.submit(clone_or_pull, repo_url, target_dir)
            for repo_url in all_repos
        ]
        for future in concurrent.futures.as_completed(futures):
            try:
                repo_url, ok = future.result()
            except Exception as exc:
                logger.exception("repo_worker_failed", error=str(exc))
                return 1
            if not ok:
                failed.add(repo_url)

    if failed:
        for repo_url in sorted(failed):
            logger.error("repo_failed", repo_url=repo_url)
        return 1

    logger.info("sync_complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
