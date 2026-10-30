"""Fast-forward checkouts while preserving staged, unstaged and untracked changes."""

import os
import stat
import subprocess
from pathlib import Path

from structlog.stdlib import get_logger

logger = get_logger()


def _is_bare_repo(path: Path) -> bool:
    return (
        path.is_dir()
        and _run_git(
            path, ["rev-parse", "--is-bare-repository"], capture=True
        ).stdout.strip()
        == "true"
    )


def is_managed_repo(path: Path) -> bool:
    """Accept a bare repository or a recovered repository linked to trunk."""
    if _is_bare_repo(path):
        return True
    if (path / "index").exists() or (path / "index").is_symlink():
        return False
    trunk = path.parent / "trunk"
    if not (trunk / ".git").is_file():
        return False
    common = _run_git(
        trunk, ["rev-parse", "--path-format=absolute", "--git-common-dir"], capture=True
    )
    top = _run_git(path, ["rev-parse", "--show-toplevel"], capture=True)
    return (
        common.returncode == 0
        and top.returncode == 0
        and Path(common.stdout.strip()).resolve() == path.resolve()
        and Path(top.stdout.strip()).resolve() == trunk.resolve()
    )


def _normalize_recovered_repo(path: Path) -> None:
    config = path / "config"
    lock = path / "config.lock"
    fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    try:
        with os.fdopen(fd, "wb") as stream:
            os.fchmod(stream.fileno(), stat.S_IMODE(config.stat().st_mode))
            stream.write(config.read_bytes())
        for args in (["--unset-all", "core.worktree"], ["core.bare", "true"]):
            result = _run_git(
                path, ["config", "--file", str(lock), *args], capture=True
            )
            if result.returncode != 0:
                raise RuntimeError(f"cannot update {config}: {result.stdout.strip()}")
        lock.replace(config)
    finally:
        lock.unlink(missing_ok=True)


def prepare_bare_layout(repo_root: Path, *, dry_run: bool = False) -> tuple[bool, str]:
    """Keep old worktree references valid when moving the bare repository."""
    bare = repo_root / ".git"
    alias = repo_root / "worktree.git"
    if bare.is_symlink():
        return False, f"invalid .git symlink: {bare}"
    if alias.is_symlink():
        if alias.readlink() != Path(".git") or not bare.is_dir():
            return False, f"invalid worktree.git symlink: {alias}"
    elif alias.exists():
        if bare.exists():
            return False, f"both {bare} and {alias} exist"
        if not is_managed_repo(alias):
            return False, f"{alias} is not a supported Git repository"
        if not dry_run:
            if not _is_bare_repo(alias):
                _normalize_recovered_repo(alias)
            alias.rename(bare)
            try:
                alias.symlink_to(".git", target_is_directory=True)
            except OSError:
                bare.rename(alias)
                raise
    if bare.exists():
        if not is_managed_repo(bare):
            return False, f"{bare} is not a supported Git repository"
        if not alias.is_symlink() and not dry_run:
            alias.symlink_to(".git", target_is_directory=True)
        if not dry_run and not _is_bare_repo(bare):
            _normalize_recovered_repo(bare)
    return True, "bare layout ready"


def _run_git(
    repo_path: Path, args: list[str], *, capture: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo_path), *args],
        check=False,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.STDOUT if capture else subprocess.DEVNULL,
        text=True,
        timeout=300,
    )


def update_checkout(
    repo_path: Path, *, dry_run: bool = False, upstream: str | None = None
) -> bool:
    bare = _run_git(repo_path, ["rev-parse", "--is-bare-repository"], capture=True)
    branch = _run_git(
        repo_path, ["symbolic-ref", "--quiet", "--short", "HEAD"], capture=True
    )
    if bare.stdout.strip() == "true" or branch.returncode != 0:
        return True
    if upstream is None:
        tracking = _run_git(
            repo_path,
            ["rev-parse", "--verify", "--symbolic-full-name", "@{upstream}"],
            capture=True,
        )
        if tracking.returncode != 0:
            logger.info(
                "checkout_update_skip", worktree=str(repo_path), reason="no upstream"
            )
            return True
        upstream = tracking.stdout.strip()
    if dry_run:
        logger.info(
            "checkout_update", worktree=str(repo_path), upstream=upstream, dry_run=True
        )
        return True

    git_dir = _run_git(repo_path, ["rev-parse", "--absolute-git-dir"], capture=True)
    status = _run_git(repo_path, ["status", "--porcelain"], capture=True)
    conflicts = _run_git(
        repo_path, ["diff", "--name-only", "--diff-filter=U"], capture=True
    )
    if (
        git_dir.returncode != 0
        or status.returncode != 0
        or conflicts.returncode != 0
        or conflicts.stdout.strip()
        or any(
            (Path(git_dir.stdout.strip()) / name).exists()
            for name in (
                "MERGE_HEAD",
                "CHERRY_PICK_HEAD",
                "REVERT_HEAD",
                "rebase-merge",
                "rebase-apply",
            )
        )
    ):
        logger.warning(
            "checkout_update_failed",
            worktree=str(repo_path),
            reason="cannot update checkout with unresolved conflicts or an operation in progress",
        )
        return False
    if (
        _run_git(
            repo_path, ["merge-base", "--is-ancestor", upstream, "HEAD"]
        ).returncode
        == 0
    ):
        return True

    stash = None
    if status.stdout.strip():
        previous = _run_git(
            repo_path, ["rev-parse", "--verify", "refs/stash"], capture=True
        )
        saved = _run_git(
            repo_path,
            [
                "stash",
                "push",
                "--include-untracked",
                "--message",
                f"repos update: {repo_path}",
            ],
            capture=True,
        )
        if saved.returncode != 0:
            logger.warning(
                "checkout_stash_failed", worktree=str(repo_path), output=saved.stdout
            )
            return False
        stash_ref = _run_git(
            repo_path, ["rev-parse", "--verify", "refs/stash"], capture=True
        )
        if (
            stash_ref.returncode != 0
            or stash_ref.stdout.strip() == (previous.stdout or "").strip()
        ):
            logger.warning(
                "checkout_stash_failed",
                worktree=str(repo_path),
                reason="could not identify saved stash; leaving checkout unchanged",
            )
            return False
        stash = stash_ref.stdout.strip()

    restored = True
    try:
        merged = _run_git(
            repo_path,
            ["merge", "--ff-only", "--no-autostash", "--no-overwrite-ignore", upstream],
            capture=True,
        )
        if merged.returncode != 0:
            logger.warning(
                "checkout_update_failed", worktree=str(repo_path), output=merged.stdout
            )
    finally:
        if stash is not None:
            applied = _run_git(
                repo_path, ["stash", "apply", "--index", stash], capture=True
            )
            restored = applied.returncode == 0
            if restored:
                # Stashes are shared by worktrees; drop only the entry we restored.
                entries = _run_git(
                    repo_path, ["stash", "list", "--format=%H %gd"], capture=True
                )
                for entry in (entries.stdout or "").splitlines():
                    oid, ref = entry.split(" ", 1)
                    if oid == stash:
                        dropped = _run_git(
                            repo_path, ["stash", "drop", ref], capture=True
                        )
                        if dropped.returncode != 0:
                            logger.warning(
                                "checkout_stash_drop_failed",
                                worktree=str(repo_path),
                                stash=stash,
                                output=dropped.stdout,
                            )
                        break
            else:
                logger.warning(
                    "checkout_restore_failed",
                    worktree=str(repo_path),
                    stash=stash,
                    reason="resolve conflicts before continuing; saved changes remain in stash",
                    output=applied.stdout,
                )
    return merged.returncode == 0 and restored
