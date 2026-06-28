#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "dotenv",
#     "niquests",
#     "structlog",
# ]
# ///

import argparse
import base64
import datetime as dt
import os
import subprocess
import sys
from concurrent.futures import Future, ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import quote

import niquests as http
from dotenv import load_dotenv
from structlog.stdlib import get_logger

# --- LOAD CONFIG ---
load_dotenv()
ORG_URL = os.getenv("AZDO_ORG_URL", "https://dev.azure.com/Thaumatorium/")
PAT = os.getenv("AZDO_PAT")

# --- CONSTANTS ---
API_BASE = f"{ORG_URL.rstrip('/')}/_apis"
basic_auth = base64.b64encode(f":{PAT}".encode("utf-8")).decode("utf-8") if PAT else ""
HEADERS = {"Authorization": f"Basic {basic_auth}"} if basic_auth else {}
PROJECT_ROOT = Path("~/dev").expanduser()
MAX_WORKERS = 4

# Timeouts (seconds)
TIMEOUT = 15
FETCH_TIMEOUT = 30
ALL_BRANCH_REFSPEC = "+refs/heads/*:refs/remotes/origin/*"
ALL_TAG_REFSPEC = "+refs/tags/*:refs/tags/*"
DEFAULT_BRANCHES = ("main", "master", "dev")

logger = get_logger()


def prioritize_repos(repos: list[dict]) -> list[dict]:
    def sort_key(repo: dict) -> tuple[int, str]:
        name = str(repo.get("name", ""))
        is_odin = name.lower().startswith("odin-")
        return (0 if is_odin else 1, name.lower())

    return sorted(repos, key=sort_key)


def run_git(
    args: list[str],
    repo_path: Path | None = None,
    capture: bool = False,
    git_configs: list[str] | None = None,
) -> subprocess.CompletedProcess[str]:
    base = ["git"]
    for config in git_configs or []:
        base += ["-c", config]
    if repo_path is not None:
        base += ["-C", str(repo_path)]
    return subprocess.run(
        base + args,
        timeout=TIMEOUT,
        capture_output=capture,
        text=capture,
    )


def run_git_with_git_dir(
    args: list[str],
    git_dir: Path,
    capture: bool = False,
    git_configs: list[str] | None = None,
) -> subprocess.CompletedProcess[str]:
    base = ["git"]
    for config in git_configs or []:
        base += ["-c", config]
    base += ["--git-dir", str(git_dir)]
    return subprocess.run(
        base + args,
        timeout=TIMEOUT,
        capture_output=capture,
        text=capture,
    )


def repo_is_bare_repo(repo_path: Path) -> bool:
    proc = run_git(["rev-parse", "--is-bare-repository"], repo_path, capture=True)
    return proc.returncode == 0 and proc.stdout.strip() == "true"


def cleanup_partial(repo_path: Path):
    if not repo_path.exists():
        return
    try:
        for root, dirs, files in os.walk(repo_path, topdown=False):
            for name in files:
                (Path(root) / name).unlink(missing_ok=True)
            for name in dirs:
                (Path(root) / name).rmdir()
        repo_path.rmdir()
    except Exception as e:  # noqa: BLE001
        logger.warning("cleanup_failed", repo_path=str(repo_path), error=str(e))


def get_projects():
    url = f"{API_BASE}/projects?api-version=7.0"
    resp = http.get(url, headers=HEADERS, timeout=TIMEOUT)
    resp.raise_for_status()
    return [{"id": p["id"], "name": p["name"]} for p in resp.json()["value"]]


def get_repos(project_id: str, project_name: str):
    url = (
        f"{ORG_URL.rstrip('/')}/{quote(project_name)}/_apis/git/repositories"
        f"?api-version=7.0"
    )
    resp = http.get(url, headers=HEADERS, timeout=TIMEOUT)
    resp.raise_for_status()
    repos = resp.json()["value"]
    return [
        repo for repo in repos if (repo.get("project") or {}).get("id") == project_id
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Clone/update Azure DevOps bare repos and sync worktrees.",
    )
    parser.add_argument(
        "--protocol",
        choices=("ssh", "http"),
        default="http",
        help="Preferred git transport for clone/update URLs (default: http).",
    )
    parser.add_argument(
        "--http",
        action="store_const",
        const="http",
        dest="protocol",
        help="Shortcut for --protocol http.",
    )
    parser.add_argument(
        "--ssh",
        action="store_const",
        const="ssh",
        dest="protocol",
        help="Shortcut for --protocol ssh.",
    )
    parser.add_argument(
        "--root",
        default=str(PROJECT_ROOT),
        help="Root folder for projects (default: ~/dev).",
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


def select_clone_url(repo: dict[str, str], protocol: str) -> str | None:
    if protocol == "http":
        return repo.get("remoteUrl") or repo.get("sshUrl")
    return repo.get("sshUrl") or repo.get("remoteUrl")


def git_auth_configs(repo_url: str) -> list[str]:
    if not repo_url.startswith(("http://", "https://")):
        return []
    return [
        "credential.interactive=false",
        f"http.extraHeader=Authorization: Basic {basic_auth}",
    ]


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


def branch_fetch_refspec(branch: str) -> str:
    return f"+refs/heads/{branch}:refs/remotes/origin/{branch}"


def tag_fetch_refspec(tag: str) -> str:
    return f"+refs/tags/{tag}:refs/tags/{tag}"


def list_remote_heads(repo_url: str, auth_configs: list[str]) -> set[str]:
    proc = run_git(
        ["ls-remote", "--heads", repo_url],
        capture=True,
        git_configs=auth_configs,
    )
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


def list_remote_tags(repo_url: str, auth_configs: list[str]) -> set[str]:
    proc = run_git(
        ["ls-remote", "--tags", "--refs", repo_url],
        capture=True,
        git_configs=auth_configs,
    )
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


def get_remote_default_branch(repo_url: str, auth_configs: list[str]) -> str | None:
    proc = run_git(
        ["ls-remote", "--symref", repo_url, "HEAD"],
        capture=True,
        git_configs=auth_configs,
    )
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


def resolve_selected_branches(
    repo_url: str,
    auth_configs: list[str],
    branches: list[str] | None,
) -> list[str]:
    remote_heads = list_remote_heads(repo_url, auth_configs)
    if branches is None:
        return sorted(remote_heads)

    selected = [branch for branch in branches if branch in remote_heads]
    if selected:
        return selected

    default_branch = get_remote_default_branch(repo_url, auth_configs)
    if default_branch:
        return [default_branch]

    if remote_heads:
        return [sorted(remote_heads)[0]]
    return []


def resolve_selected_tags(
    repo_url: str,
    auth_configs: list[str],
    tags: list[str],
    all_tags: bool,
) -> list[str]:
    remote_tags = list_remote_tags(repo_url, auth_configs)
    if all_tags:
        return sorted(remote_tags)
    return [tag for tag in tags if tag in remote_tags]


def ensure_fetch_refspecs(
    bare_dir: Path,
    branch_refspecs: list[str],
    include_all_tags: bool,
    tag_refspecs: list[str],
):
    run_git(["config", "--unset-all", "remote.origin.fetch"], bare_dir)

    for refspec in branch_refspecs:
        run_git(["config", "--add", "remote.origin.fetch", refspec], bare_dir)

    if include_all_tags:
        run_git(["config", "--add", "remote.origin.fetch", ALL_TAG_REFSPEC], bare_dir)
    else:
        for refspec in tag_refspecs:
            run_git(["config", "--add", "remote.origin.fetch", refspec], bare_dir)


def list_worktree_paths(bare_dir: Path, git_configs: list[str]) -> set[Path]:
    proc = run_git_with_git_dir(
        ["worktree", "list", "--porcelain"],
        bare_dir,
        capture=True,
        git_configs=git_configs,
    )
    if proc.returncode != 0:
        return set()

    paths: set[Path] = set()
    for line in proc.stdout.splitlines():
        if line.startswith("worktree "):
            paths.add(Path(line.removeprefix("worktree ").strip()))
    return paths


def local_branch_exists(bare_dir: Path, branch: str, git_configs: list[str]) -> bool:
    proc = run_git_with_git_dir(
        ["show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
        bare_dir,
        capture=False,
        git_configs=git_configs,
    )
    return proc.returncode == 0


def worktree_is_dirty(repo_path: Path, git_configs: list[str]) -> bool:
    proc = run_git(
        ["status", "--porcelain"],
        repo_path=repo_path,
        capture=True,
        git_configs=git_configs,
    )
    if proc.returncode != 0:
        return True
    return bool(proc.stdout.strip())


def ensure_branch_worktrees(
    bare_dir: Path,
    branches_root: Path,
    branches: list[str],
    git_configs: list[str],
) -> tuple[bool, str, set[Path]]:
    branches_root.mkdir(parents=True, exist_ok=True)
    expected: set[Path] = set()

    for branch in branches:
        target = branches_root / sanitize_worktree_name(branch)
        expected.add(target)
        target.parent.mkdir(parents=True, exist_ok=True)

        if not target.exists():
            if local_branch_exists(bare_dir, branch, git_configs):
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

            add_proc = run_git_with_git_dir(
                add_args,
                bare_dir,
                capture=True,
                git_configs=git_configs,
            )
            if add_proc.returncode != 0:
                reason = (
                    add_proc.stderr or add_proc.stdout or "git worktree add failed"
                ).strip()
                return False, f"branch worktree add {branch}: {reason}", expected
            logger.info(
                "worktree_branch_add",
                target=str(target),
                branch=branch,
            )

        set_upstream = run_git(
            ["branch", "--set-upstream-to", f"origin/{branch}", branch],
            repo_path=target,
            capture=True,
            git_configs=git_configs,
        )
        if set_upstream.returncode != 0:
            logger.warning(
                "worktree_branch_set_upstream_failed",
                target=str(target),
                branch=branch,
                error=set_upstream.stderr.strip(),
            )

        if worktree_is_dirty(target, git_configs):
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
            git_configs=git_configs,
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
        logger.info(
            "worktree_branch_update",
            target=str(target),
            branch=branch,
        )

    return True, "branch worktrees synced", expected


def ensure_tag_worktrees(
    bare_dir: Path,
    tags_root: Path,
    tags: list[str],
    git_configs: list[str],
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
                git_configs=git_configs,
            )
            if add_proc.returncode != 0:
                reason = (
                    add_proc.stderr or add_proc.stdout or "git worktree add failed"
                ).strip()
                return False, f"tag worktree add {tag}: {reason}", expected
            logger.info(
                "worktree_tag_add",
                target=str(target),
                tag=tag,
            )

        if worktree_is_dirty(target, git_configs):
            logger.warning(
                "worktree_tag_dirty_skip",
                target=str(target),
                tag=tag,
                reason="local changes detected; skipping update to avoid data loss",
            )
            continue

        checkout_proc = run_git(
            ["checkout", "--detach", tag],
            repo_path=target,
            capture=True,
            git_configs=git_configs,
        )
        if checkout_proc.returncode != 0:
            reason = (
                checkout_proc.stderr or checkout_proc.stdout or "git checkout failed"
            ).strip()
            return False, f"tag worktree update {tag}: {reason}", expected
        logger.info(
            "worktree_tag_update",
            target=str(target),
            tag=tag,
        )

    return True, "tag worktrees synced", expected


def prune_stale_worktrees(
    bare_dir: Path,
    git_configs: list[str],
    branches_root: Path,
    tags_root: Path,
    expected_paths: set[Path],
):
    existing = list_worktree_paths(bare_dir, git_configs)
    for worktree_path in sorted(existing):
        if worktree_path in expected_paths:
            continue
        if not (
            worktree_path.is_relative_to(branches_root)
            or worktree_path.is_relative_to(tags_root)
        ):
            continue

        if worktree_is_dirty(worktree_path, git_configs):
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
            git_configs=git_configs,
        )
        if remove_proc.returncode == 0:
            logger.info("worktree_pruned", worktree_path=str(worktree_path))

    run_git_with_git_dir(["worktree", "prune"], bare_dir, git_configs=git_configs)


def maybe_migrate_legacy_repo(repo_root: Path) -> tuple[bool, str]:
    bare_dir = repo_root / "bare.git"
    if bare_dir.exists() or not repo_root.exists():
        return True, "no migration needed"

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
        logger.info("legacy_repo_migrated", bare_dir=str(bare_dir))
        return True, "migrated"
    except Exception as e:  # noqa: BLE001
        return False, str(e)


def clone_or_update_repo(
    repo_url: str,
    repo_root: Path,
    requested_branches: list[str] | None,
    requested_tags: list[str],
    all_tags: bool,
    sync_worktrees: bool,
    prune_worktrees_flag: bool,
) -> tuple[bool, str]:
    def _repo_identity(url: str) -> str:
        if not url:
            return ""
        u = url.rstrip("/")
        if ":" in u and "//" not in u:
            path_part = u.split(":", 1)[1]
        else:
            path_part = u.split("://", 1)[-1].split("/", 1)[-1]
        parts = [
            part for part in path_part.split("/") if part and part not in {"_git", "v3"}
        ]
        normalized = [part.removesuffix(".git") for part in parts]
        return "/".join(normalized[-2:])

    def urls_equivalent(a: str, b: str) -> bool:
        return bool(_repo_identity(a)) and _repo_identity(a) == _repo_identity(b)

    ok, reason = maybe_migrate_legacy_repo(repo_root)
    if not ok:
        return False, f"legacy migration failed: {reason}"

    bare_dir = repo_root / "bare.git"
    branches_root = repo_root / "branches"
    tags_root = repo_root / "tags"
    checkouts_root = repo_root / "checkouts"

    auth_configs = git_auth_configs(repo_url)

    if bare_dir.exists():
        if not repo_is_bare_repo(bare_dir):
            return False, f"{bare_dir} exists but is not a bare git repo"

        origin_proc = run_git(
            ["remote", "get-url", "origin"],
            bare_dir,
            capture=True,
            git_configs=auth_configs,
        )
        origin_url = origin_proc.stdout.strip() if origin_proc.returncode == 0 else ""
        if origin_url and not urls_equivalent(origin_url, repo_url):
            return False, f"origin url mismatch ({origin_url} != {repo_url})"
    else:
        bare_dir.parent.mkdir(parents=True, exist_ok=True)
        clone_proc = run_git(
            ["clone", "--bare", repo_url, str(bare_dir)],
            capture=True,
            git_configs=auth_configs,
        )
        if clone_proc.returncode != 0:
            reason = (
                clone_proc.stderr or clone_proc.stdout or "git clone failed"
            ).strip()
            if bare_dir.exists():
                cleanup_partial(bare_dir)
            return False, reason
        logger.info("repo_cloned", repo_url=repo_url, bare_dir=str(bare_dir))

    branches_root.mkdir(parents=True, exist_ok=True)
    tags_root.mkdir(parents=True, exist_ok=True)
    checkouts_root.mkdir(parents=True, exist_ok=True)

    selected_branches = resolve_selected_branches(
        repo_url, auth_configs, requested_branches
    )
    selected_tags = resolve_selected_tags(
        repo_url, auth_configs, requested_tags, all_tags
    )

    branch_refspecs = [
        (
            ALL_BRANCH_REFSPEC
            if requested_branches is None
            else branch_fetch_refspec(branch)
        )
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
            fetch_args,
            bare_dir,
            capture=True,
            git_configs=auth_configs,
        )
    except subprocess.TimeoutExpired:
        return False, f"timeout during fetch (>{FETCH_TIMEOUT}s)"

    if fetch_proc.returncode != 0:
        reason = (fetch_proc.stderr or fetch_proc.stdout or "git fetch failed").strip()
        return False, reason

    logger.info("repo_updated", bare_dir=str(bare_dir))

    if not sync_worktrees:
        return True, "bare repo updated"

    expected_paths: set[Path] = set()

    branches_ok, branches_reason, branch_paths = ensure_branch_worktrees(
        bare_dir,
        branches_root,
        selected_branches,
        auth_configs,
    )
    expected_paths.update(branch_paths)
    if not branches_ok:
        return False, branches_reason

    tags_ok, tags_reason, tag_paths = ensure_tag_worktrees(
        bare_dir,
        tags_root,
        selected_tags,
        auth_configs,
    )
    expected_paths.update(tag_paths)
    if not tags_ok:
        return False, tags_reason

    if prune_worktrees_flag:
        prune_stale_worktrees(
            bare_dir,
            auth_configs,
            branches_root,
            tags_root,
            expected_paths,
        )

    return True, "updated"


def summarize(
    total: int,
    successes: int,
    failures: list[tuple[str, str]],
    started_at: dt.datetime,
):
    elapsed = dt.datetime.now() - started_at
    logger.info(
        "summary",
        total=total,
        updated=successes,
        failures=len(failures),
        elapsed=str(elapsed),
    )
    for repo_name, reason in failures:
        logger.error("summary_failure", repo_name=repo_name, reason=reason)


def main() -> int:
    args = parse_args()
    if not ORG_URL or not PAT:
        sys.exit("Missing AZDO_ORG_URL or AZDO_PAT in .env")

    root = Path(args.root).expanduser()
    requested_branches = None if args.all_branches else parse_csv(args.branches)
    requested_tags = parse_csv(args.tags)

    started_at = dt.datetime.now()
    try:
        projects = get_projects()
    except Exception as e:  # noqa: BLE001
        sys.exit(f"Failed to list projects: {e}")

    total_repos = 0
    successes = 0
    failures: list[tuple[str, str]] = []

    for project in projects:
        project_id = project["id"]
        project_name = project["name"]
        try:
            repos = get_repos(project_id, project_name)
        except Exception as e:  # noqa: BLE001
            logger.error(
                "project_skipped",
                project_name=project_name,
                error=str(e),
            )
            continue

        repos = prioritize_repos(repos)

        total_repos += len(repos)
        project_dir = root / project_name
        project_dir.mkdir(parents=True, exist_ok=True)

        tasks: list[tuple[str, Future[tuple[bool, str]]]] = []
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            for repo in repos:
                repo_name = repo["name"]
                clone_url = select_clone_url(repo, args.protocol)
                if not clone_url:
                    logger.warning(
                        "repo_skipped_no_clone_url",
                        project_name=project_name,
                        repo_name=repo_name,
                    )
                    failures.append((f"{project_name}/{repo_name}", "no clone url"))
                    continue

                repo_root = project_dir / repo_name
                tasks.append(
                    (
                        f"{project_name}/{repo_name}",
                        executor.submit(
                            clone_or_update_repo,
                            clone_url,
                            repo_root,
                            requested_branches,
                            requested_tags,
                            args.all_tags,
                            args.worktrees,
                            args.prune_worktrees,
                        ),
                    )
                )

            future_map: dict[Future[tuple[bool, str]], str] = {
                future: repo_name for repo_name, future in tasks
            }
            for task in as_completed(future_map.keys()):
                repo_name = future_map[task]
                ok, reason = task.result()
                if ok:
                    successes += 1
                else:
                    failures.append((repo_name, reason))

    summarize(total_repos, successes, failures, started_at)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
