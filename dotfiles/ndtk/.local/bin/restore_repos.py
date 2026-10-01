#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "structlog==26.1.0",
# ]
# ///

from __future__ import annotations

import concurrent.futures
import datetime as dt
import os
import shutil
from pathlib import Path

import click
import grab

DEFAULT_REPOS_FILE = (
    Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    / "ndtk/repos.dat"
)


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


@click.group()
def cli() -> None:
    """Restore a fixed repository list, including non-GitHub remotes."""


@cli.command("check")
@click.option(
    "--repos-file",
    type=click.Path(path_type=Path, dir_okay=False),
    default=DEFAULT_REPOS_FILE,
    show_default=True,
)
def check_command(repos_file: Path) -> None:
    """Check Git and the configured repository inventory."""
    errors: list[str] = []
    if shutil.which("git") is None:
        errors.append("missing executable: git")
    if not repos_file.expanduser().is_file():
        errors.append(f"missing repository list: {repos_file.expanduser()}")
    if errors:
        raise click.ClickException("\n".join(errors))
    click.echo("OK")


@cli.command("restore")
@click.argument(
    "target_dir",
    required=False,
    type=click.Path(path_type=Path, file_okay=False),
    default=Path.home() / "dev",
)
@click.option(
    "--repos-file",
    type=click.Path(path_type=Path, dir_okay=False),
    default=DEFAULT_REPOS_FILE,
    show_default=True,
    help="Repository list to restore.",
)
@click.option(
    "-j",
    "--jobs",
    type=int,
    help="Number of parallel jobs. Defaults to JOBS, otherwise min(cpu_count, 8).",
)
@click.option(
    "--branches",
    default=",".join(grab.DEFAULT_BRANCHES),
    help=(
        "Comma-separated branch names for flat worktrees (used only when --no-all-branches is set)."
    ),
)
@click.option(
    "--all-branches/--no-all-branches",
    default=True,
    help="Track all remote branches as flat worktrees (default: enabled).",
)
@click.option(
    "--tags",
    default="",
    help="Comma-separated tag names for detached flat worktrees.",
)
@click.option(
    "--all-tags/--no-all-tags",
    default=True,
    help="Track all remote tags as detached flat worktrees (default: enabled).",
)
@click.option(
    "--worktrees/--no-worktrees",
    default=True,
    help="Sync flat branch and tag worktrees (default: enabled).",
)
@click.option(
    "--prune-worktrees",
    is_flag=True,
    help="Remove stale flat worktrees not in target set.",
)
@click.option(
    "--fetch-timeout",
    type=int,
    default=grab.DEFAULT_FETCH_TIMEOUT,
    show_default=True,
    help="Timeout in seconds for 'git fetch' per repository.",
)
@click.option(
    "--dry-run",
    is_flag=True,
    help="Read the inventory and validate remotes without cloning, fetching, or writing.",
)
@click.pass_context
def restore_command(
    ctx: click.Context,
    target_dir: Path,
    repos_file: Path,
    jobs: int | None,
    branches: str,
    all_branches: bool,
    tags: str,
    all_tags: bool,
    worktrees: bool,
    prune_worktrees: bool,
    fetch_timeout: int,
    dry_run: bool,
) -> None:
    """Restore repositories from the configured inventory."""
    ctx.exit(
        run_restore(
            target_dir,
            repos_file,
            jobs,
            branches,
            all_branches,
            tags,
            all_tags,
            worktrees,
            prune_worktrees,
            fetch_timeout,
            dry_run,
        )
    )


def run_restore(
    target_dir: Path,
    repos_file: Path,
    jobs: int | None,
    branches: str,
    all_branches: bool,
    tags: str,
    all_tags: bool,
    worktrees: bool,
    prune_worktrees: bool,
    fetch_timeout: int,
    dry_run: bool,
) -> int:
    grab.configure_logging()
    if not grab.require("git"):
        return 1

    repos_file = repos_file.expanduser()
    if not repos_file.exists():
        grab.logger.error("repo_list_missing", repos_file=str(repos_file))
        return 1

    target_dir = target_dir.expanduser()
    if not dry_run:
        target_dir.mkdir(parents=True, exist_ok=True)
    requested_branches = None if all_branches else grab.parse_csv(branches)
    requested_tags = grab.parse_csv(tags)

    all_repos = read_repo_urls(repos_file)
    if not all_repos:
        grab.logger.info("no_repositories_found", repos_file=str(repos_file))
        return 0

    jobs = grab.detect_jobs(jobs)
    started_at = dt.datetime.now(dt.UTC)
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
                all_tags,
                worktrees,
                prune_worktrees,
                fetch_timeout,
                dry_run,
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
        elapsed=str(dt.datetime.now(dt.UTC) - started_at),
    )
    return 1 if failed else 0


if __name__ == "__main__":
    cli()
