#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "structlog==26.1.0",
# ]
# ///

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlparse

import structlog as sl
import structlog.contextvars as cv
import structlog.stdlib as log

# Load the shared module installed by Home Manager.
sys.path.insert(0, str(Path.home() / ".local" / "bin"))
from repo_timestamps import ensure_dprint_config_link, refresh_repository_tree  # noqa: E402

ALL_BRANCH_REFSPEC = "+refs/heads/*:refs/remotes/origin/*"
ALL_TAG_REFSPEC = "+refs/tags/*:refs/tags/*"
DEFAULT_BRANCHES = ("master",)
DEFAULT_INITIAL_BRANCH = "master"
DEFAULT_FETCH_TIMEOUT = 300
TIMEOUT = 300
BARE_REPO_DIR = "worktree.git"
RESERVED_WORKTREE_NAMES = {
    BARE_REPO_DIR,
    "branches",
    "tags",
    "checkouts",
}

logger = log.get_logger(__name__)


@dataclass
class RepoTrace:
    repo_url: str
    repo: str
    started_monotonic: float = field(default_factory=time.monotonic)
    actions: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    branches_selected: list[str] = field(default_factory=list)
    tags_selected: list[str] = field(default_factory=list)
    worktrees_enabled: bool = True
    prune_worktrees: bool = False
    fetch_timeout_seconds: int = DEFAULT_FETCH_TIMEOUT

    def add_action(self, message: str) -> None:
        self.actions.append(message)

    def add_warning(self, message: str) -> None:
        self.warnings.append(message)

    def finish(self, ok: bool, reason: str) -> None:
        emit = logger.info if ok else logger.error
        emit(
            "repo_sync",
            repo=self.repo,
            repo_url=self.repo_url,
            ok=ok,
            reason=reason,
            elapsed_ms=round((time.monotonic() - self.started_monotonic) * 1000),
            worktrees_enabled=self.worktrees_enabled,
            prune_worktrees=self.prune_worktrees,
            fetch_timeout_seconds=self.fetch_timeout_seconds,
            branches=self.branches_selected,
            tags=self.tags_selected,
            actions=self.actions,
            warnings=self.warnings,
        )


def finish_repo_trace(
    trace_ctx: RepoTrace, ok: bool, reason: str
) -> tuple[str, bool, str]:
    trace_ctx.finish(ok, reason)
    return trace_ctx.repo_url, ok, reason


def fail_repo_trace(trace_ctx: RepoTrace, reason: str) -> tuple[str, bool, str]:
    return finish_repo_trace(trace_ctx, False, reason)


def succeed_repo_trace(trace_ctx: RepoTrace, reason: str) -> tuple[str, bool, str]:
    return finish_repo_trace(trace_ctx, True, reason)


def configure_logging() -> None:
    sl.configure(
        processors=[
            cv.merge_contextvars,
            sl.processors.TimeStamper(fmt="iso"),
            sl.processors.add_log_level,
            sl.dev.ConsoleRenderer(colors=sys.stderr.isatty()),
        ],
        wrapper_class=sl.make_filtering_bound_logger("debug"),
        logger_factory=sl.PrintLoggerFactory(file=sys.stderr),
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
    return subprocess.run(  # noqa: S603 - callers construct the command arguments
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


def gh_api_paginated(endpoint: str, params: dict[str, str]) -> object:
    args = ["api", "--method", "GET", "--paginate", "--slurp", endpoint]
    for key, value in params.items():
        args.extend(["-f", f"{key}={value}"])
    return gh_json(args)


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


def is_pull_request_tag(tag: str) -> bool:
    return "-PR-" in tag


def unique_worktree_name(name: str, occupied: set[str], prefix: str) -> str:
    candidate = name
    while candidate in occupied or candidate in RESERVED_WORKTREE_NAMES:
        candidate = f"{prefix}-{candidate}"
    return candidate


def branch_worktree_name(branch: str) -> str:
    name = "trunk" if branch == "master" else sanitize_worktree_name(branch)
    return unique_worktree_name(name, set(), "branch")


def tag_worktree_name(tag: str, branches: list[str]) -> str:
    branch_names = {branch_worktree_name(branch) for branch in branches}
    return unique_worktree_name(sanitize_worktree_name(tag), branch_names, "tag")


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


def set_repo_mtime_to_latest_commit(repo_root: Path, bare_dir: Path) -> None:
    stats = refresh_repository_tree(repo_root, bare_dir=bare_dir)
    logger.info(
        "repo_timestamps_updated",
        repo_root=str(repo_root),
        files=stats.files_updated,
        directories=stats.directories_updated,
        worktrees=stats.worktrees_scanned,
    )


def cleanup_partial(repo_path: Path, trace: RepoTrace | None = None) -> None:
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
        message = f"cleanup failed for {repo_path}: {exc}"
        if trace is None:
            logger.warning("cleanup_failed", repo_path=str(repo_path), error=str(exc))
        else:
            trace.add_warning(message)


def branch_fetch_refspec(branch: str) -> str:
    return f"+refs/heads/{branch}:refs/remotes/origin/{branch}"


def tag_fetch_refspec(tag: str) -> str:
    return f"+refs/tags/{tag}:refs/tags/{tag}"


def list_remote_heads(repo_url: str) -> set[str] | None:
    proc = run_git(["ls-remote", "--heads", repo_url], capture=True)
    if proc.returncode != 0:
        return None

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
    if remote_heads is None:
        return []

    if branches is None:
        return sorted(remote_heads)

    selected = [branch for branch in branches if branch in remote_heads]
    if selected:
        return selected

    default_branch = get_remote_default_branch(repo_url)
    if default_branch:
        return [default_branch]

    if remote_heads:
        return [min(remote_heads)]
    return []


def initialize_empty_remote_repo(repo_url: str, trace: RepoTrace) -> tuple[bool, str]:
    repo_name = Path(repo_path_part(repo_url)).name
    with tempfile.TemporaryDirectory(prefix=f"grab-{repo_name}-") as tmp:
        tmp_path = Path(tmp)
        init_proc = run_git(
            ["init", "--initial-branch", DEFAULT_INITIAL_BRANCH],
            tmp_path,
            capture=True,
        )
        if init_proc.returncode != 0:
            reason = (init_proc.stderr or init_proc.stdout or "git init failed").strip()
            return False, reason

        (tmp_path / ".gitignore").write_text("")
        add_proc = run_git(["add", ".gitignore"], tmp_path, capture=True)
        if add_proc.returncode != 0:
            reason = (add_proc.stderr or add_proc.stdout or "git add failed").strip()
            return False, reason

        commit_message = f"{repo_name}: initialize repository"
        commit_proc = run_git(["commit", "-m", commit_message], tmp_path, capture=True)
        if commit_proc.returncode != 0:
            reason = (
                commit_proc.stderr or commit_proc.stdout or "git commit failed"
            ).strip()
            return False, reason

        remote_proc = run_git(
            ["remote", "add", "origin", repo_url],
            tmp_path,
            capture=True,
        )
        if remote_proc.returncode != 0:
            reason = (
                remote_proc.stderr or remote_proc.stdout or "git remote add failed"
            ).strip()
            return False, reason

        push_proc = run_git(
            ["push", "-u", "origin", DEFAULT_INITIAL_BRANCH],
            tmp_path,
            capture=True,
            timeout=DEFAULT_FETCH_TIMEOUT,
        )
        if push_proc.returncode != 0:
            reason = (push_proc.stderr or push_proc.stdout or "git push failed").strip()
            return False, reason

    trace.add_action(f"empty remote initialized: {DEFAULT_INITIAL_BRANCH}")
    return True, "empty remote initialized"


def resolve_selected_tags(repo_url: str, tags: list[str], all_tags: bool) -> list[str]:
    remote_tags = list_remote_tags(repo_url)
    if all_tags:
        return [tag for tag in sorted(remote_tags) if not is_pull_request_tag(tag)]
    return [tag for tag in tags if tag in remote_tags and not is_pull_request_tag(tag)]


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


def remote_branch_exists(bare_dir: Path, branch: str) -> bool:
    proc = run_git_with_git_dir(
        ["show-ref", "--verify", "--quiet", f"refs/remotes/origin/{branch}"],
        bare_dir,
    )
    return proc.returncode == 0


def ensure_local_branch_from_origin(
    bare_dir: Path, branch: str, trace: RepoTrace
) -> tuple[bool, str]:
    if local_branch_exists(bare_dir, branch):
        return True, "branch exists"

    if not remote_branch_exists(bare_dir, branch):
        return False, f"origin/{branch} does not exist"

    create_proc = run_git_with_git_dir(
        [
            "update-ref",
            f"refs/heads/{branch}",
            f"refs/remotes/origin/{branch}",
        ],
        bare_dir,
        capture=True,
    )
    if create_proc.returncode != 0:
        reason = (
            create_proc.stderr or create_proc.stdout or "failed to create local branch"
        ).strip()
        return False, reason

    trace.add_action(f"local branch created from origin: {branch}")
    return True, "branch created"


def bare_head_target(bare_dir: Path) -> str | None:
    proc = run_git_with_git_dir(["symbolic-ref", "-q", "HEAD"], bare_dir, capture=True)
    if proc.returncode != 0:
        return None
    return proc.stdout.strip()


def ensure_bare_head(
    bare_dir: Path, preferred_branch: str | None, trace: RepoTrace
) -> tuple[bool, str]:
    current_head = bare_head_target(bare_dir)
    if current_head:
        head_branch = current_head.removeprefix("refs/heads/")
        if local_branch_exists(bare_dir, head_branch):
            return True, "head already valid"

    candidates: list[str] = []
    if preferred_branch:
        candidates.append(preferred_branch)
    for fallback in DEFAULT_BRANCHES:
        if fallback not in candidates:
            candidates.append(fallback)

    for branch in candidates:
        ok, reason = ensure_local_branch_from_origin(bare_dir, branch, trace)
        if not ok:
            continue
        set_head_proc = run_git_with_git_dir(
            ["symbolic-ref", "HEAD", f"refs/heads/{branch}"],
            bare_dir,
            capture=True,
        )
        if set_head_proc.returncode != 0:
            reason = (
                set_head_proc.stderr
                or set_head_proc.stdout
                or "failed to set bare HEAD"
            ).strip()
            return False, reason
        trace.add_action(f"bare HEAD repaired: {branch}")
        return True, "head repaired"

    return False, "unable to repair bare HEAD from fetched origin branches"


def worktree_is_dirty(repo_path: Path) -> bool:
    proc = run_git(["status", "--porcelain"], repo_path=repo_path, capture=True)
    if proc.returncode != 0:
        return True
    return bool(proc.stdout.strip())


def ensure_branch_worktrees(
    bare_dir: Path,
    repo_root: Path,
    branches: list[str],
    trace: RepoTrace,
) -> tuple[bool, str, set[Path]]:
    expected: set[Path] = set()

    for branch in branches:
        target = repo_root / branch_worktree_name(branch)
        expected.add(target)
        target.parent.mkdir(parents=True, exist_ok=True)

        if target.exists() and not (target / ".git").exists():
            return (
                False,
                f"branch worktree target exists but is not a git worktree: {target}",
                expected,
            )

        if not target.exists():
            ok, reason = ensure_local_branch_from_origin(bare_dir, branch, trace)
            if not ok:
                return False, f"branch setup {branch}: {reason}", expected

            add_args = ["worktree", "add", str(target), branch]

            add_proc = run_git_with_git_dir(add_args, bare_dir, capture=True)
            if add_proc.returncode != 0:
                reason = (
                    add_proc.stderr or add_proc.stdout or "git worktree add failed"
                ).strip()
                return False, f"branch worktree add {branch}: {reason}", expected
            trace.add_action(f"branch worktree added: {branch}")

        if ensure_dprint_config_link(target):
            trace.add_action(f"dprint config linked: {branch}")

        set_upstream = run_git(
            ["branch", "--set-upstream-to", f"origin/{branch}", branch],
            repo_path=target,
            capture=True,
        )
        if set_upstream.returncode != 0:
            trace.add_warning(
                f"branch upstream set failed: {branch}: {(set_upstream.stderr or set_upstream.stdout).strip()}"
            )

        if worktree_is_dirty(target):
            trace.add_warning(f"branch update skipped (dirty worktree): {branch}")
            continue

        ff_only_proc = run_git(
            ["merge", "--ff-only", f"origin/{branch}"],
            repo_path=target,
            capture=True,
        )
        if ff_only_proc.returncode != 0:
            trace.add_warning(
                f"branch update skipped: {branch}: {(ff_only_proc.stderr or ff_only_proc.stdout or 'non-fast-forward').strip()}"
            )
            continue
        trace.add_action(f"branch worktree updated: {branch}")

    return True, "branch worktrees synced", expected


def ensure_tag_worktrees(
    bare_dir: Path,
    repo_root: Path,
    tags: list[str],
    branches: list[str],
    trace: RepoTrace,
) -> tuple[bool, str, set[Path]]:
    expected: set[Path] = set()

    for tag in tags:
        target = repo_root / tag_worktree_name(tag, branches)
        expected.add(target)
        target.parent.mkdir(parents=True, exist_ok=True)

        if target.exists() and not (target / ".git").exists():
            return (
                False,
                f"tag worktree target exists but is not a git worktree: {target}",
                expected,
            )

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
            trace.add_action(f"tag worktree added: {tag}")

        if ensure_dprint_config_link(target):
            trace.add_action(f"dprint config linked: {tag}")

        if worktree_is_dirty(target):
            trace.add_warning(f"tag update skipped (dirty worktree): {tag}")
            continue

        checkout_proc = run_git(
            ["checkout", "--detach", tag], repo_path=target, capture=True
        )
        if checkout_proc.returncode != 0:
            reason = (
                checkout_proc.stderr or checkout_proc.stdout or "git checkout failed"
            ).strip()
            return False, f"tag worktree update {tag}: {reason}", expected
        trace.add_action(f"tag worktree updated: {tag}")

    return True, "tag worktrees synced", expected


def prune_stale_worktrees(
    bare_dir: Path,
    repo_root: Path,
    expected_paths: set[Path],
    trace: RepoTrace,
) -> None:
    existing = list_worktree_paths(bare_dir)
    for worktree_path in sorted(existing):
        if worktree_path in expected_paths:
            continue
        if is_pull_request_tag(worktree_path.name):
            continue
        if (
            worktree_path.parent != repo_root
            or worktree_path.name in RESERVED_WORKTREE_NAMES
        ):
            continue

        if worktree_is_dirty(worktree_path):
            trace.add_warning(f"worktree prune skipped (dirty): {worktree_path}")
            continue

        remove_proc = run_git_with_git_dir(
            ["worktree", "remove", str(worktree_path)],
            bare_dir,
            capture=True,
        )
        if remove_proc.returncode == 0:
            trace.add_action(f"worktree pruned: {worktree_path}")

    run_git_with_git_dir(["worktree", "prune"], bare_dir)


def maybe_migrate_legacy_bare_repo(
    repo_root: Path, trace: RepoTrace | None = None
) -> tuple[bool, str]:
    bare_dir = repo_root / BARE_REPO_DIR
    if bare_dir.exists() or not repo_root.exists():
        return True, "no migration needed"

    if (repo_root / ".git").exists():
        return False, (
            f"{repo_root} is a normal checkout. Move it aside before syncing this repo into {BARE_REPO_DIR} plus flat worktree layout."
        )

    if not repo_is_bare_repo(repo_root):
        return True, "no migration needed"

    message = f"{repo_root} is a legacy bare repository. Move it aside before syncing this repo into {BARE_REPO_DIR} plus flat worktree layout."
    if trace is not None:
        trace.add_warning(message)
    return False, message


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
    fetch_timeout: int,
    dry_run: bool = False,
) -> tuple[str, bool, str]:
    org_and_repo = repo_path_part(repo_url)
    with cv.bound_contextvars(repo=org_and_repo, repo_url=repo_url):
        trace_ctx = RepoTrace(
            repo_url=repo_url,
            repo=org_and_repo,
            worktrees_enabled=sync_worktrees,
            prune_worktrees=prune_worktrees_flag,
            fetch_timeout_seconds=fetch_timeout,
        )
        repo_root = target_dir / org_and_repo
        bare_dir = repo_root / BARE_REPO_DIR
        if dry_run:
            if bare_dir.exists() and not repo_is_bare_repo(bare_dir):
                return fail_repo_trace(
                    trace_ctx, f"{bare_dir} exists but is not a bare git repo"
                )
            remote_heads = list_remote_heads(repo_url)
            if remote_heads is None:
                return fail_repo_trace(trace_ctx, "unable to list remote branches")
            selected_branches = resolve_selected_branches(repo_url, requested_branches)
            selected_tags = resolve_selected_tags(repo_url, requested_tags, all_tags)
            trace_ctx.branches_selected = selected_branches
            trace_ctx.tags_selected = selected_tags
            action = "update" if bare_dir.exists() else "clone"
            trace_ctx.add_action(f"would {action} {bare_dir}")
            return succeed_repo_trace(trace_ctx, f"dry-run: would {action}")

        ok, reason = maybe_migrate_legacy_bare_repo(repo_root, trace_ctx)
        if not ok:
            return fail_repo_trace(trace_ctx, reason)

        if bare_dir.exists():
            if not repo_is_bare_repo(bare_dir):
                reason = f"{bare_dir} exists but is not a bare git repo"
                return fail_repo_trace(trace_ctx, reason)

            origin_proc = run_git(
                ["remote", "get-url", "origin"], bare_dir, capture=True
            )
            origin_url = (
                origin_proc.stdout.strip() if origin_proc.returncode == 0 else ""
            )
            if origin_url and not urls_equivalent(origin_url, repo_url):
                reason = f"origin url mismatch ({origin_url} != {repo_url})"
                return fail_repo_trace(trace_ctx, reason)
        else:
            bare_dir.parent.mkdir(parents=True, exist_ok=True)
            clone_proc = run_git(
                ["clone", "--bare", repo_url, str(bare_dir)], capture=True
            )
            if clone_proc.returncode != 0:
                reason = (
                    clone_proc.stderr or clone_proc.stdout or "git clone failed"
                ).strip()
                if bare_dir.exists():
                    cleanup_partial(bare_dir, trace_ctx)
                return fail_repo_trace(trace_ctx, reason)
            trace_ctx.add_action(f"{BARE_REPO_DIR} cloned")

        remote_heads = list_remote_heads(repo_url)
        if remote_heads is None:
            return fail_repo_trace(trace_ctx, "unable to list remote branches")
        if not remote_heads:
            init_ok, init_reason = initialize_empty_remote_repo(repo_url, trace_ctx)
            if not init_ok:
                return fail_repo_trace(trace_ctx, init_reason)

        selected_branches = resolve_selected_branches(repo_url, requested_branches)
        selected_tags = resolve_selected_tags(repo_url, requested_tags, all_tags)
        trace_ctx.branches_selected = selected_branches
        trace_ctx.tags_selected = selected_tags

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
            fetch_proc = run_git(
                fetch_args, bare_dir, capture=True, timeout=fetch_timeout
            )
        except subprocess.TimeoutExpired:
            reason = f"timeout during fetch (>{fetch_timeout}s)"
            return fail_repo_trace(trace_ctx, reason)

        if fetch_proc.returncode != 0:
            reason = (
                fetch_proc.stderr or fetch_proc.stdout or "git fetch failed"
            ).strip()
            return fail_repo_trace(trace_ctx, reason)

        trace_ctx.add_action(f"{BARE_REPO_DIR} fetched")

        preferred_head_branch = selected_branches[0] if selected_branches else None
        head_ok, head_reason = ensure_bare_head(
            bare_dir, preferred_head_branch, trace_ctx
        )
        if not head_ok:
            return fail_repo_trace(trace_ctx, head_reason)

        if not sync_worktrees:
            set_repo_mtime_to_latest_commit(repo_root, bare_dir)
            return succeed_repo_trace(trace_ctx, f"{BARE_REPO_DIR} updated")

        expected_paths: set[Path] = set()

        branches_ok, branches_reason, branch_paths = ensure_branch_worktrees(
            bare_dir,
            repo_root,
            selected_branches,
            trace_ctx,
        )
        expected_paths.update(branch_paths)
        if not branches_ok:
            return fail_repo_trace(trace_ctx, branches_reason)

        tags_ok, tags_reason, tag_paths = ensure_tag_worktrees(
            bare_dir,
            repo_root,
            selected_tags,
            selected_branches,
            trace_ctx,
        )
        expected_paths.update(tag_paths)
        if not tags_ok:
            return fail_repo_trace(trace_ctx, tags_reason)

        if prune_worktrees_flag:
            prune_stale_worktrees(bare_dir, repo_root, expected_paths, trace_ctx)

        set_repo_mtime_to_latest_commit(repo_root, bare_dir)
        return succeed_repo_trace(trace_ctx, "updated")


def iter_repo_records(pages: object) -> list[dict[str, object]]:
    if not isinstance(pages, list):
        return []

    records: list[dict[str, object]] = []
    for page in pages:
        if isinstance(page, list):
            records.extend(repo for repo in page if isinstance(repo, dict))
        elif isinstance(page, dict):
            records.append(page)
    return records


def repo_urls_from_api(endpoint: str, params: dict[str, str]) -> list[str]:
    repos = iter_repo_records(gh_api_paginated(endpoint, params))
    urls: list[str] = []
    for repo in repos:
        url = repo.get("ssh_url")
        if isinstance(url, str):
            urls.append(url)
    return urls


def personal_repo_urls() -> list[str]:
    return repo_urls_from_api(
        "/user/repos",
        {
            "affiliation": "owner",
            "per_page": "100",
            "visibility": "all",
        },
    )


def org_repo_urls(org: str) -> list[str]:
    return repo_urls_from_api(
        f"/orgs/{org}/repos",
        {
            "per_page": "100",
            "type": "all",
        },
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            f"Clone/update all personal and organization GitHub repositories using {BARE_REPO_DIR} plus flat branch and tag worktrees."
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
            "Comma-separated branch names for flat worktrees (used only when --no-all-branches is set)."
        ),
    )
    parser.add_argument(
        "--all-branches",
        action="store_true",
        default=False,
        help="Track all remote branches as flat worktrees (default: disabled).",
    )
    parser.add_argument(
        "--no-all-branches",
        action="store_false",
        dest="all_branches",
        help=argparse.SUPPRESS,
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
        help=f"Disable worktree sync and only update {BARE_REPO_DIR} repositories.",
    )
    parser.add_argument(
        "--prune-worktrees",
        action="store_true",
        help="Remove stale flat worktrees not in target set.",
    )
    parser.add_argument(
        "--fetch-timeout",
        type=int,
        default=DEFAULT_FETCH_TIMEOUT,
        help=(
            f"Timeout in seconds for 'git fetch' per repository. Default: {DEFAULT_FETCH_TIMEOUT}."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Discover repositories and validate remote selections without writing or fetching.",
    )
    return parser.parse_args(argv)


def run_tests(argv: list[str]) -> int:
    import unittest
    from unittest import mock

    parser = argparse.ArgumentParser(
        prog=f"{Path(sys.argv[0]).name} tests",
        description="Run grab.py self-tests.",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    class GrabTests(unittest.TestCase):
        def test_gh_api_paginated_uses_get_paginate_and_slurp(self) -> None:
            with mock.patch(
                f"{__name__}.gh_json",
                return_value=[[]],
            ) as gh_json_mock:
                result = gh_api_paginated(
                    "/user/repos",
                    {"affiliation": "owner", "per_page": "100"},
                )

            assert result == [[]]
            gh_json_mock.assert_called_once_with(
                [
                    "api",
                    "--method",
                    "GET",
                    "--paginate",
                    "--slurp",
                    "/user/repos",
                    "-f",
                    "affiliation=owner",
                    "-f",
                    "per_page=100",
                ]
            )

        def test_iter_repo_records_flattens_paginated_api_pages(self) -> None:
            records = iter_repo_records(
                [
                    [{"ssh_url": "git@github.com:NostraDavid/nixcfg.git"}, "noise"],
                    {"ssh_url": "git@github.com:NostraDavid/ndat.git"},
                    None,
                ]
            )

            assert records == [
                {"ssh_url": "git@github.com:NostraDavid/nixcfg.git"},
                {"ssh_url": "git@github.com:NostraDavid/ndat.git"},
            ]

        def test_repo_urls_from_api_keeps_only_ssh_urls(self) -> None:
            pages = [
                [
                    {"ssh_url": "git@github.com:NostraDavid/ndat.git"},
                    {"ssh_url": None},
                    {"html_url": "https://github.com/NostraDavid/nixcfg"},
                ],
                [{"ssh_url": "git@github.com:NostraDavid/nixcfg.git"}],
            ]
            with mock.patch(
                f"{__name__}.gh_api_paginated",
                return_value=pages,
            ) as api_mock:
                urls = repo_urls_from_api("/user/repos", {"per_page": "100"})

            assert urls == [
                "git@github.com:NostraDavid/ndat.git",
                "git@github.com:NostraDavid/nixcfg.git",
            ]
            api_mock.assert_called_once_with("/user/repos", {"per_page": "100"})

        def test_personal_repo_urls_uses_authenticated_owner_endpoint(self) -> None:
            with mock.patch(
                f"{__name__}.repo_urls_from_api",
                return_value=[],
            ) as urls_mock:
                personal_repo_urls()

            urls_mock.assert_called_once_with(
                "/user/repos",
                {
                    "affiliation": "owner",
                    "per_page": "100",
                    "visibility": "all",
                },
            )

        def test_org_repo_urls_uses_org_endpoint(self) -> None:
            with mock.patch(
                f"{__name__}.repo_urls_from_api",
                return_value=[],
            ) as urls_mock:
                org_repo_urls("Thaumatorium")

            urls_mock.assert_called_once_with(
                "/orgs/Thaumatorium/repos",
                {
                    "per_page": "100",
                    "type": "all",
                },
            )

        def test_repo_path_part_handles_github_urls(self) -> None:
            cases = {
                "git@github.com:NostraDavid/ndat.git": "NostraDavid/ndat",
                "https://github.com/NostraDavid/ndat.git": "NostraDavid/ndat",
                "ssh://git@example.test/repo.git": "repo",
                "/home/david/dev/repo": "repo",
            }
            for raw_url, expected in cases.items():
                with self.subTest(raw_url=raw_url):
                    assert repo_path_part(raw_url) == expected

        def test_parse_csv_deduplicates_and_ignores_blanks(self) -> None:
            assert parse_csv(" master,main,,master, release ") == [
                "master",
                "main",
                "release",
            ]

        def test_clone_or_update_dry_run_never_runs_git(self) -> None:
            with (
                tempfile.TemporaryDirectory() as tmp_dir,
                mock.patch(f"{__name__}.list_remote_heads", return_value={"main"}),
                mock.patch(
                    f"{__name__}.resolve_selected_branches",
                    return_value=["main"],
                ),
                mock.patch(f"{__name__}.resolve_selected_tags", return_value=[]),
                mock.patch(f"{__name__}.run_git") as run_git_mock,
            ):
                _url, ok, reason = clone_or_update_repo(
                    "git@example.test:team/repo.git",
                    Path(tmp_dir),
                    ["main"],
                    [],
                    False,
                    True,
                    False,
                    DEFAULT_FETCH_TIMEOUT,
                    True,
                )

            assert ok
            assert reason == "dry-run: would clone"
            run_git_mock.assert_not_called()

        def test_repo_mtime_uses_latest_commit_timestamp(self) -> None:
            with (
                tempfile.TemporaryDirectory() as tmp_dir,
                mock.patch(f"{__name__}.refresh_repository_tree") as refresh_mock,
            ):
                repo_root = Path(tmp_dir)
                bare_dir = repo_root / BARE_REPO_DIR
                set_repo_mtime_to_latest_commit(repo_root, bare_dir)
                refresh_mock.assert_called_once_with(repo_root, bare_dir=bare_dir)

    suite = unittest.defaultTestLoader.loadTestsFromTestCase(GrabTests)
    runner = unittest.TextTestRunner(verbosity=2 if args.verbose else 1)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv == ["check"]:
        errors = [
            f"missing executable: {name}"
            for name in ("git", "gh")
            if shutil.which(name) is None
        ]
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        print("OK")
        return 0
    if argv and argv[0] == "tests":
        return run_tests(argv[1:])

    configure_logging()
    args = parse_args(argv)
    if not require("gh"):
        return 1

    target_dir = args.target_dir.expanduser()
    if not args.dry_run:
        target_dir.mkdir(parents=True, exist_ok=True)
    requested_branches = None if args.all_branches else parse_csv(args.branches)
    requested_tags = parse_csv(args.tags)

    jobs = detect_jobs(args.jobs)
    started_at = dt.datetime.now(dt.UTC)
    logger.info("sync_started", target_dir=str(target_dir), jobs=jobs)

    user = gh_text(["api", "user", "--jq", ".login"])

    logger.info("gathering_personal_repos", user=user)
    personal_repos = personal_repo_urls()

    logger.info("gathering_organization_repos")
    org_repos: list[str] = []
    orgs = gh_text(["api", "user/orgs", "--jq", ".[].login"]).splitlines()
    for org in orgs:
        logger.info("gathering_org_repos", org=org)
        org_repos.extend(org_repo_urls(org))

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
                args.fetch_timeout,
                args.dry_run,
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

    logger.info(
        "sync_complete",
        total=len(all_repos),
        failed=len(failed),
        elapsed=str(dt.datetime.now(dt.UTC) - started_at),
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
