#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "structlog>=26.1.0",
# ]
# ///

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

import structlog as sl
from structlog.stdlib import get_logger

ALL_BRANCH_REFSPEC = "+refs/heads/*:refs/remotes/origin/*"
ALL_TAG_REFSPEC = "+refs/tags/*:refs/tags/*"
DEFAULT_BRANCHES = ("main", "master", "dev")
FETCH_TIMEOUT = 60
TIMEOUT = 30

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
    timeout: int = TIMEOUT,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        timeout=timeout,
    )


def run_git(
    args: list[str],
    repo_path: Path | None = None,
    *,
    capture: bool = False,
    timeout: int = TIMEOUT,
) -> subprocess.CompletedProcess[str]:
    base = ["git"]
    if repo_path is not None:
        base += ["-C", str(repo_path)]
    return run(base + args, capture=capture, timeout=timeout)


def run_git_with_git_dir(
    args: list[str],
    git_dir: Path,
    *,
    capture: bool = False,
    timeout: int = TIMEOUT,
) -> subprocess.CompletedProcess[str]:
    return run(
        ["git", "--git-dir", str(git_dir), *args],
        capture=capture,
        timeout=timeout,
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


def parse_csv(raw: str) -> list[str]:
    seen: set[str] = set()
    values: list[str] = []
    for part in raw.split(","):
        value = part.strip()
        if not value or value in seen:
            continue
        seen.add(value)
        values.append(value)
    return values


def sanitize_worktree_name(ref_name: str) -> str:
    return ref_name.strip().replace("/", "-")


def repo_path_part(repo_url: str) -> str:
    cleaned = repo_url.strip().rstrip("/").removesuffix(".git")

    if cleaned.startswith("git@github.com:"):
        return cleaned.removeprefix("git@github.com:")

    parsed = urlparse(cleaned)
    if parsed.scheme:
        path = parsed.path.strip("/")
        if parsed.hostname in {"github.com", "www.github.com"} and path.count("/") >= 1:
            return path
        return Path(path).name

    if ":" in cleaned and not cleaned.startswith("/"):
        return cleaned.split(":", 1)[1]

    return Path(cleaned).name


def repo_is_bare_repo(repo_path: Path) -> bool:
    proc = run_git(["rev-parse", "--is-bare-repository"], repo_path, capture=True)
    return proc.returncode == 0 and proc.stdout.strip() == "true"


def cleanup_partial(repo_path: Path) -> None:
    if not repo_path.exists():
        return
    try:
        for root, dirs, files in os.walk(repo_path, topdown=False):
            for name in files:
                (Path(root) / name).unlink(missing_ok=True)
            for name in dirs:
                (Path(root) / name).rmdir()
        repo_path.rmdir()
    except Exception as exc:  # noqa: BLE001
        logger.warning("cleanup_failed", repo_path=str(repo_path), error=str(exc))


def branch_fetch_refspec(branch: str) -> str:
    return f"+refs/heads/{branch}:refs/remotes/origin/{branch}"


def tag_fetch_refspec(tag: str) -> str:
    return f"+refs/tags/{tag}:refs/tags/{tag}"


def list_remote_heads(repo_url: str) -> set[str]:
    proc = run_git(["ls-remote", "--heads", repo_url], capture=True)
    if proc.returncode != 0:
        return set()

    heads: set[str] = set()
    for line in proc.stdout.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        ref = parts[1].strip()
        prefix = "refs/heads/"
        if ref.startswith(prefix):
            heads.add(ref.removeprefix(prefix))
    return heads


def list_remote_tags(repo_url: str) -> set[str]:
    proc = run_git(["ls-remote", "--tags", "--refs", repo_url], capture=True)
    if proc.returncode != 0:
        return set()

    tags: set[str] = set()
    for line in proc.stdout.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        ref = parts[1].strip()
        prefix = "refs/tags/"
        if ref.startswith(prefix):
            tags.add(ref.removeprefix(prefix))
    return tags


def get_remote_default_branch(repo_url: str) -> str | None:
    proc = run_git(["ls-remote", "--symref", repo_url, "HEAD"], capture=True)
    if proc.returncode != 0:
        return None

    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line.startswith("ref: ") or not line.endswith("\tHEAD"):
            continue
        ref = line.removeprefix("ref: ").split("\t", 1)[0]
        prefix = "refs/heads/"
        if ref.startswith(prefix):
            return ref.removeprefix(prefix)
    return None


def resolve_selected_branches(repo_url: str, branches: list[str] | None) -> list[str]:
    remote_heads = list_remote_heads(repo_url)
    if branches is None:
        return sorted(remote_heads)

    selected = [branch for branch in branches if branch in remote_heads]
    if selected:
        return selected

    default_branch = get_remote_default_branch(repo_url)
    if default_branch:
        return [default_branch]

    if remote_heads:
        return [sorted(remote_heads)[0]]
    return []


def resolve_selected_tags(repo_url: str, tags: list[str], all_tags: bool) -> list[str]:
    remote_tags = list_remote_tags(repo_url)
    if all_tags:
        return sorted(remote_tags)
    return [tag for tag in tags if tag in remote_tags]


def ensure_fetch_refspecs(
    bare_dir: Path,
    branch_refspecs: list[str],
    include_all_tags: bool,
    tag_refspecs: list[str],
) -> None:
    run_git(["config", "--unset-all", "remote.origin.fetch"], bare_dir)

    for refspec in branch_refspecs:
        run_git(["config", "--add", "remote.origin.fetch", refspec], bare_dir)

    if include_all_tags:
        run_git(["config", "--add", "remote.origin.fetch", ALL_TAG_REFSPEC], bare_dir)
    else:
        for refspec in tag_refspecs:
            run_git(["config", "--add", "remote.origin.fetch", refspec], bare_dir)


def list_worktree_paths(bare_dir: Path) -> set[Path]:
    proc = run_git_with_git_dir(
        ["worktree", "list", "--porcelain"], bare_dir, capture=True
    )
    if proc.returncode != 0:
        return set()

    paths: set[Path] = set()
    for line in proc.stdout.splitlines():
        if line.startswith("worktree "):
            paths.add(Path(line.removeprefix("worktree ").strip()))
    return paths


def local_branch_exists(bare_dir: Path, branch: str) -> bool:
    proc = run_git_with_git_dir(
        ["show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
        bare_dir,
    )
    return proc.returncode == 0


def worktree_is_dirty(repo_path: Path) -> bool:
    proc = run_git(["status", "--porcelain"], repo_path=repo_path, capture=True)
    if proc.returncode != 0:
        return True
    return bool(proc.stdout.strip())


def ensure_branch_worktrees(
    bare_dir: Path,
    branches_root: Path,
    branches: list[str],
) -> tuple[bool, str, set[Path]]:
    branches_root.mkdir(parents=True, exist_ok=True)
    expected: set[Path] = set()

    for branch in branches:
        target = branches_root / sanitize_worktree_name(branch)
        expected.add(target)
        target.parent.mkdir(parents=True, exist_ok=True)

        if not target.exists():
            if local_branch_exists(bare_dir, branch):
                add_args = ["worktree", "add", str(target), branch]
            else:
                add_args = [
                    "worktree",
                    "add",
                    "-b",
                    branch,
                    str(target),
                    f"origin/{branch}",
                ]

            add_proc = run_git_with_git_dir(add_args, bare_dir, capture=True)
            if add_proc.returncode != 0:
                reason = (
                    add_proc.stderr or add_proc.stdout or "git worktree add failed"
                ).strip()
                return False, f"branch worktree add {branch}: {reason}", expected
            logger.info("worktree_branch_add", target=str(target), branch=branch)

        set_upstream = run_git(
            ["branch", "--set-upstream-to", f"origin/{branch}", branch],
            repo_path=target,
            capture=True,
        )
        if set_upstream.returncode != 0:
            logger.warning(
                "worktree_branch_set_upstream_failed",
                target=str(target),
                branch=branch,
                error=(set_upstream.stderr or set_upstream.stdout).strip(),
            )

        if worktree_is_dirty(target):
            logger.warning(
                "worktree_branch_dirty_skip",
                target=str(target),
                branch=branch,
                reason="local changes detected; skipping update to avoid data loss",
            )
            continue

        ff_only_proc = run_git(
            ["merge", "--ff-only", f"origin/{branch}"],
            repo_path=target,
            capture=True,
        )
        if ff_only_proc.returncode != 0:
            logger.warning(
                "worktree_branch_update_skipped",
                target=str(target),
                branch=branch,
                reason=(
                    ff_only_proc.stderr
                    or ff_only_proc.stdout
                    or "non-fast-forward; leaving local branch unchanged"
                ).strip(),
            )
            continue
        logger.info("worktree_branch_update", target=str(target), branch=branch)

    return True, "branch worktrees synced", expected


def ensure_tag_worktrees(
    bare_dir: Path,
    tags_root: Path,
    tags: list[str],
) -> tuple[bool, str, set[Path]]:
    tags_root.mkdir(parents=True, exist_ok=True)
    expected: set[Path] = set()

    for tag in tags:
        target = tags_root / sanitize_worktree_name(tag)
        expected.add(target)
        target.parent.mkdir(parents=True, exist_ok=True)

        if not target.exists():
            add_proc = run_git_with_git_dir(
                ["worktree", "add", "--detach", str(target), tag],
                bare_dir,
                capture=True,
            )
            if add_proc.returncode != 0:
                reason = (
                    add_proc.stderr or add_proc.stdout or "git worktree add failed"
                ).strip()
                return False, f"tag worktree add {tag}: {reason}", expected
            logger.info("worktree_tag_add", target=str(target), tag=tag)

        if worktree_is_dirty(target):
            logger.warning(
                "worktree_tag_dirty_skip",
                target=str(target),
                tag=tag,
                reason="local changes detected; skipping update to avoid data loss",
            )
            continue

        checkout_proc = run_git(
            ["checkout", "--detach", tag], repo_path=target, capture=True
        )
        if checkout_proc.returncode != 0:
            reason = (
                checkout_proc.stderr or checkout_proc.stdout or "git checkout failed"
            ).strip()
            return False, f"tag worktree update {tag}: {reason}", expected
        logger.info("worktree_tag_update", target=str(target), tag=tag)

    return True, "tag worktrees synced", expected


def prune_stale_worktrees(
    bare_dir: Path,
    branches_root: Path,
    tags_root: Path,
    expected_paths: set[Path],
) -> None:
    existing = list_worktree_paths(bare_dir)
    for worktree_path in sorted(existing):
        if worktree_path in expected_paths:
            continue
        if not (
            worktree_path.is_relative_to(branches_root)
            or worktree_path.is_relative_to(tags_root)
        ):
            continue

        if worktree_is_dirty(worktree_path):
            logger.warning(
                "worktree_prune_dirty_skip",
                worktree_path=str(worktree_path),
                reason="local changes detected; skipping prune to avoid data loss",
            )
            continue

        remove_proc = run_git_with_git_dir(
            ["worktree", "remove", str(worktree_path)],
            bare_dir,
            capture=True,
        )
        if remove_proc.returncode == 0:
            logger.info("worktree_pruned", worktree_path=str(worktree_path))

    run_git_with_git_dir(["worktree", "prune"], bare_dir)


def maybe_migrate_legacy_bare_repo(repo_root: Path) -> tuple[bool, str]:
    bare_dir = repo_root / "bare.git"
    if bare_dir.exists() or not repo_root.exists():
        return True, "no migration needed"

    if (repo_root / ".git").exists():
        return False, (
            f"{repo_root} is a normal checkout. Move it aside before syncing "
            "this repo into bare.git/branches/tags layout."
        )

    if not repo_is_bare_repo(repo_root):
        return True, "no migration needed"

    migrating = repo_root.parent / f"{repo_root.name}.bare.git.migrating"
    if migrating.exists():
        return False, f"migration temp already exists: {migrating}"

    try:
        repo_root.rename(migrating)
        repo_root.mkdir(parents=True, exist_ok=True)
        migrating.rename(bare_dir)
        (repo_root / "branches").mkdir(parents=True, exist_ok=True)
        (repo_root / "tags").mkdir(parents=True, exist_ok=True)
        (repo_root / "checkouts").mkdir(parents=True, exist_ok=True)
        logger.info("legacy_bare_repo_migrated", bare_dir=str(bare_dir))
        return True, "migrated"
    except Exception as exc:  # noqa: BLE001
        return False, str(exc)


def urls_equivalent(a: str, b: str) -> bool:
    return repo_path_part(a) == repo_path_part(b)


def clone_or_update_repo(
    repo_url: str,
    target_dir: Path,
    requested_branches: list[str] | None,
    requested_tags: list[str],
    all_tags: bool,
    sync_worktrees: bool,
    prune_worktrees_flag: bool,
) -> tuple[str, bool, str]:
    org_and_repo = repo_path_part(repo_url)
    repo_root = target_dir / org_and_repo
    ok, reason = maybe_migrate_legacy_bare_repo(repo_root)
    if not ok:
        return repo_url, False, reason

    bare_dir = repo_root / "bare.git"
    branches_root = repo_root / "branches"
    tags_root = repo_root / "tags"
    checkouts_root = repo_root / "checkouts"

    if bare_dir.exists():
        if not repo_is_bare_repo(bare_dir):
            return repo_url, False, f"{bare_dir} exists but is not a bare git repo"

        origin_proc = run_git(["remote", "get-url", "origin"], bare_dir, capture=True)
        origin_url = origin_proc.stdout.strip() if origin_proc.returncode == 0 else ""
        if origin_url and not urls_equivalent(origin_url, repo_url):
            return repo_url, False, f"origin url mismatch ({origin_url} != {repo_url})"
    else:
        bare_dir.parent.mkdir(parents=True, exist_ok=True)
        clone_proc = run_git(["clone", "--bare", repo_url, str(bare_dir)], capture=True)
        if clone_proc.returncode != 0:
            reason = (
                clone_proc.stderr or clone_proc.stdout or "git clone failed"
            ).strip()
            if bare_dir.exists():
                cleanup_partial(bare_dir)
            return repo_url, False, reason
        logger.info("repo_cloned", repo=org_and_repo, bare_dir=str(bare_dir))

    branches_root.mkdir(parents=True, exist_ok=True)
    tags_root.mkdir(parents=True, exist_ok=True)
    checkouts_root.mkdir(parents=True, exist_ok=True)

    selected_branches = resolve_selected_branches(repo_url, requested_branches)
    selected_tags = resolve_selected_tags(repo_url, requested_tags, all_tags)

    branch_refspecs = [
        ALL_BRANCH_REFSPEC
        if requested_branches is None
        else branch_fetch_refspec(branch)
        for branch in selected_branches
    ]
    if requested_branches is None:
        branch_refspecs = [ALL_BRANCH_REFSPEC]

    tag_refspecs = [tag_fetch_refspec(tag) for tag in selected_tags]
    ensure_fetch_refspecs(
        bare_dir,
        branch_refspecs,
        include_all_tags=all_tags,
        tag_refspecs=tag_refspecs,
    )

    fetch_args = ["fetch", "--prune", "--prune-tags", "origin", *branch_refspecs]
    if all_tags:
        fetch_args.append(ALL_TAG_REFSPEC)
    else:
        fetch_args.extend(tag_refspecs)

    try:
        fetch_proc = run_git(fetch_args, bare_dir, capture=True, timeout=FETCH_TIMEOUT)
    except subprocess.TimeoutExpired:
        return repo_url, False, f"timeout during fetch (>{FETCH_TIMEOUT}s)"

    if fetch_proc.returncode != 0:
        reason = (fetch_proc.stderr or fetch_proc.stdout or "git fetch failed").strip()
        return repo_url, False, reason

    logger.info("repo_updated", repo=org_and_repo, bare_dir=str(bare_dir))

    if not sync_worktrees:
        return repo_url, True, "bare repo updated"

    expected_paths: set[Path] = set()

    branches_ok, branches_reason, branch_paths = ensure_branch_worktrees(
        bare_dir,
        branches_root,
        selected_branches,
    )
    expected_paths.update(branch_paths)
    if not branches_ok:
        return repo_url, False, branches_reason

    tags_ok, tags_reason, tag_paths = ensure_tag_worktrees(
        bare_dir,
        tags_root,
        selected_tags,
    )
    expected_paths.update(tag_paths)
    if not tags_ok:
        return repo_url, False, tags_reason

    if prune_worktrees_flag:
        prune_stale_worktrees(bare_dir, branches_root, tags_root, expected_paths)

    return repo_url, True, "updated"


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
        description=(
            "Clone/update all personal and organization GitHub repositories "
            "using bare.git plus branches/ and tags/ worktrees."
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
        "-j",
        "--jobs",
        type=int,
        help="Number of parallel jobs. Defaults to JOBS, otherwise min(cpu_count, 8).",
    )
    parser.add_argument(
        "--branches",
        default=",".join(DEFAULT_BRANCHES),
        help=(
            "Comma-separated branch names for branches/ worktrees "
            "(used only when --no-all-branches is set)."
        ),
    )
    parser.add_argument(
        "--all-branches",
        action="store_true",
        default=True,
        help="Track all remote branches under branches/ (default: enabled).",
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
        help="Comma-separated tag names for detached worktrees under tags/.",
    )
    parser.add_argument(
        "--all-tags",
        action="store_true",
        default=True,
        help="Track all remote tags under tags/ as detached worktrees (default: enabled).",
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
        help="Sync branches/ and tags/ worktrees (default: enabled).",
    )
    parser.add_argument(
        "--no-worktrees",
        action="store_false",
        dest="worktrees",
        help="Disable worktree sync and only update bare repositories.",
    )
    parser.add_argument(
        "--prune-worktrees",
        action="store_true",
        help="Remove stale entries under branches/ and tags/ not in target set.",
    )
    return parser.parse_args()


def main() -> int:
    configure_logging()
    args = parse_args()
    if not require("gh"):
        return 1

    target_dir = args.target_dir.expanduser()
    target_dir.mkdir(parents=True, exist_ok=True)
    requested_branches = None if args.all_branches else parse_csv(args.branches)
    requested_tags = parse_csv(args.tags)

    jobs = detect_jobs(args.jobs)
    started_at = datetime.now()
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

    all_repos = sorted(set(personal_repos + org_repos), key=str.casefold)

    if not all_repos:
        logger.info("no_repositories_found")
        return 0

    logger.info("processing_repositories", count=len(all_repos), jobs=jobs)

    failed: dict[str, str] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
        futures = [
            executor.submit(
                clone_or_update_repo,
                repo_url,
                target_dir,
                requested_branches,
                requested_tags,
                args.all_tags,
                args.worktrees,
                args.prune_worktrees,
            )
            for repo_url in all_repos
        ]
        for future in concurrent.futures.as_completed(futures):
            try:
                repo_url, ok, reason = future.result()
            except Exception as exc:  # noqa: BLE001
                logger.exception("repo_worker_failed", error=str(exc))
                return 1
            if not ok:
                failed[repo_url] = reason

    for repo_url, reason in sorted(failed.items()):
        logger.error("repo_failed", repo_url=repo_url, reason=reason)

    logger.info(
        "sync_complete",
        total=len(all_repos),
        failed=len(failed),
        elapsed=str(datetime.now() - started_at),
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
