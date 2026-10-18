"""Fast-forward checkouts while preserving staged, unstaged and untracked changes."""

from pathlib import Path
import subprocess

from structlog.stdlib import get_logger

logger = get_logger()


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
