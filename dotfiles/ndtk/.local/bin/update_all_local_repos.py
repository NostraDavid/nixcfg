#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "click",
#     "stamina",
#     "structlog",
# ]
# ///

"""Fetch local git repos and optionally sync tag worktrees.

This CLI walks a project directory, performs `git fetch` on each repo, and can
optionally reconcile moved remotes, missing remotes, and top-level tag worktrees.

Bitbucket calls use a default 6-second throttling delay between network-call
starts, including retries and the final non-dry-run fetch. This is separate
from the default 30-second per-fetch timeout; Azure calls are not subject to
the Bitbucket delay. Discovery is streamed into independent Bitbucket and
other-repository queues, so other fetches continue while Bitbucket is waiting.
"""

import base64
import datetime as dt
import logging
import os
import re
import shutil
import subprocess
import sys
import time
import unittest
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from queue import Queue
from tempfile import TemporaryDirectory
from threading import Event, Lock
from unittest.mock import patch
from urllib.parse import urlparse

import click  # type: ignore
import stamina  # type: ignore
import structlog  # type: ignore
import structlog.contextvars as structlog_contextvars  # type: ignore
from click.testing import CliRunner
from structlog.stdlib import get_logger  # type: ignore

# Load the shared module installed by Home Manager.
sys.path.insert(0, str(Path.home() / ".local" / "bin"))
from repo_timestamps import ensure_dprint_config_link, refresh_repository_tree  # noqa: E402

DEFAULT_PROJECT = Path("~/dev").expanduser()
DEFAULT_ENV_FILE = Path("~/dev/.env").expanduser()
BITBUCKET_HOST = os.environ.get("NDTK_BITBUCKET_HOST", "bitbucket.org")
DEFAULT_BITBUCKET_INTERVAL_SECONDS = 6
DEFAULT_BITBUCKET_TIMEOUT_SECONDS = 30.0
DEFAULT_AZURE_TIMEOUT_SECONDS = 30.0
DEFAULT_TRASH_DIR_NAME = ".trash/update_repos"
AZURE_GIT_HOSTS = frozenset(("dev.azure.com", "ssh.dev.azure.com"))
WORKTREE_GIT_DIR_NAME = "worktree.git"
TRUNK_DIR_NAME = "trunk"
__version__ = "0.1.0"

logger = get_logger()
bind_contextvars = structlog_contextvars.bind_contextvars
clear_contextvars = structlog_contextvars.clear_contextvars
unbind_contextvars = structlog_contextvars.unbind_contextvars


class RetryableFetchError(Exception):
    def __init__(self, output: str, line_count: int):
        self.output = output
        self.line_count = line_count
        super().__init__(output[-500:] if output else "retryable fetch error")


def _style_heading(text: str) -> str:
    return click.style(text, fg="green", bold=True)


def _style_cmd(text: str) -> str:
    return click.style(text, fg="cyan", bold=True)


def _style_prog(text: str) -> str:
    return click.style(text, fg="bright_blue", bold=True)


def _style_body(text: str) -> str:
    return click.style(text)


def _style_muted(text: str) -> str:
    return click.style(text, fg="bright_black")


def _style_value(text: str) -> str:
    return click.style(text, fg="yellow")


def _apply_color_option(
    ctx: click.Context, param: click.Parameter, value: str | None
) -> str | None:
    del param
    if value == "always":
        ctx.color = True
    elif value == "never":
        ctx.color = False
    return value


def _compact_toggle_option(text: str) -> str:
    match = re.fullmatch(r"--([a-z0-9-]+)\s*/\s*--no-\1", text)
    if not match:
        return text
    return f"--[no-]{match.group(1)}"


class RustCommand(click.Command):
    def format_help(self, ctx: click.Context, formatter: click.HelpFormatter) -> None:
        pieces: list[str] = []
        command_path = ctx.command_path
        pieces.append(_style_heading("Usage:"))
        pieces.append(f"  {_style_prog(command_path)} {_style_muted('[OPTIONS]')}")
        if self.help:
            pieces.append("")
            pieces.append(_style_heading("About:"))
            pieces.append(f"  {_style_body(self.help)}")

        params = self.get_params(ctx)
        if params:
            pieces.append("")
            pieces.append(_style_heading("Options:"))
            option_rows: list[tuple[str, str]] = []
            for param in params:
                record = param.get_help_record(ctx)
                if record is None:
                    continue
                opt, help_text = record
                compact_opt = _compact_toggle_option(opt)
                option_rows.append((compact_opt, help_text))
            option_width = max((len(opt) for opt, _ in option_rows), default=0) + 8
            pieces.extend(
                f"  {_style_cmd(opt):<{option_width}} {_style_body(help_text)}"
                for opt, help_text in option_rows
            )

        epilog = ctx.command.epilog
        if epilog:
            pieces.append("")
            pieces.append(_style_heading("Examples:"))
            pieces.extend(f"  {line}" if line else "" for line in epilog.splitlines())

        click.echo("\n".join(pieces), color=True)


class RustGroup(click.Group):
    command_class = RustCommand

    def format_help(self, ctx: click.Context, formatter: click.HelpFormatter) -> None:
        pieces: list[str] = []
        pieces.append(
            _style_body(
                "update_all_local_repos: Fast local git fetcher with optional branch worktree sync."
            )
        )
        pieces.append("")
        pieces.append(
            f"{_style_heading('Usage:')} {_style_prog(ctx.command_path)} {_style_prog('[OPTIONS]')} {_style_prog('<COMMAND>')}"
        )

        commands = self.list_commands(ctx)
        if commands:
            pieces.append("")
            pieces.append(_style_heading("Commands:"))
            for name in commands:
                cmd = self.get_command(ctx, name)
                short = cmd.get_short_help_str() if cmd else ""
                pieces.append(f"  {_style_cmd(name):<24} {_style_body(short)}")

        pieces.append("")
        pieces.append(_style_heading("Options:"))
        help_text = _style_body("Print help (see more with '--help')")
        version_text = _style_body("Print version")
        pieces.append(f"  {_style_cmd('-h, --help'):<34} {help_text}")
        pieces.append(f"  {_style_cmd('-V, --version'):<34} {version_text}")

        pieces.append("")
        pieces.append(_style_heading("Global options:"))
        pieces.append(
            f"  {_style_cmd('--color <WHEN>'):<24} {_style_body('Control when colored output is used')}"
        )

        pieces.append("")
        pieces.append(
            _style_body("For help with a specific command, see: ")
            + _style_prog(f"{ctx.command_path} help ")
            + _style_value("<command>")
            + _style_body(".")
        )

        click.echo("\n".join(pieces), color=True)


_URL_RE = re.compile(r"(?P<url>(?:ssh|git|https?)://[^\s'\"<>]+)")
_SCP_URL_RE = re.compile(r"(?P<url>(?:[A-Za-z0-9._-]+@)?[A-Za-z0-9._-]+:[^\s'\"<>]+)")
_SYNCED_WORKTREE_COMMON_DIRS: set[str] = set()
_LAST_BITBUCKET_CALL_AT: float | None = None


def configure_logging(verbosity: int) -> None:
    if verbosity >= 2:
        level = logging.DEBUG
    elif verbosity == 1:
        level = logging.INFO
    else:
        level = logging.WARNING

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="%H:%M:%S"),
            structlog.dev.ConsoleRenderer(colors=True),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(level),
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    logging.basicConfig(
        format="%(message)s",
        level=level,
    )
    logging.getLogger("stamina").setLevel(logging.ERROR)


def _run_git(
    repo_path: Path,
    args: list[str],
    *,
    check: bool = False,
    capture: bool = False,
    timeout: float | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(  # noqa: S603
        ["git", "-C", str(repo_path), *args],  # noqa: S607
        check=check,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.STDOUT if capture else subprocess.DEVNULL,
        text=capture,
        timeout=timeout,
        env=env,
    )


def _remaining_timeout(deadline: float | None) -> float | None:
    if deadline is None:
        return None
    return max(0.001, deadline - time.perf_counter())


def _format_timeout_output(
    exc: subprocess.TimeoutExpired, timeout_seconds: float
) -> str:
    output = exc.stdout or exc.stderr or ""
    if isinstance(output, bytes):
        output = output.decode(errors="replace")
    return f"{output}\ncommand timed out after {timeout_seconds:.1f}s".strip()


def _load_dotenv(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}

    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        logger.warning("env_file_read_failed", path=str(path), error=str(exc))
        return {}

    values: dict[str, str] = {}
    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        line = re.sub(r"^export\s+", "", line)
        key, separator, value = line.partition("=")
        key = key.strip()
        if not separator or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key] = value
    return values


def _load_azure_pat() -> str | None:
    values = _load_dotenv(DEFAULT_ENV_FILE)
    return os.environ.get("AZDO_PAT") or values.get("AZDO_PAT") or None


def _azure_git_env(
    origin_url: str | None, azure_pat: str | None
) -> dict[str, str] | None:
    if _host_from_url(origin_url) != "dev.azure.com" or not azure_pat:
        return None

    parsed = urlparse(origin_url or "")
    username = parsed.username or os.environ.get("NDTK_AZURE_USERNAME", "git")
    encoded_credentials = base64.b64encode(f"{username}:{azure_pat}".encode()).decode(
        "ascii"
    )

    env = os.environ.copy()
    try:
        config_count = max(0, int(env.get("GIT_CONFIG_COUNT", "0")))
    except ValueError:
        config_count = 0
    env[f"GIT_CONFIG_KEY_{config_count}"] = "credential.helper"
    env[f"GIT_CONFIG_VALUE_{config_count}"] = ""
    env[f"GIT_CONFIG_KEY_{config_count + 1}"] = (
        f"http.https://{parsed.hostname or 'dev.azure.com'}/.extraheader"
    )
    env[f"GIT_CONFIG_VALUE_{config_count + 1}"] = (
        f"Authorization: Basic {encoded_credentials}"
    )
    env["GIT_CONFIG_COUNT"] = str(config_count + 2)
    env["GIT_TERMINAL_PROMPT"] = "0"
    return env


def _azure_git_helper_env(origin_url: str | None) -> dict[str, str] | None:
    if _host_from_url(origin_url) not in AZURE_GIT_HOSTS:
        return None

    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    return env


def _is_azure_auth_error(fetch_output: str) -> bool:
    lowered = fetch_output.lower()
    patterns = (
        "authentication failed",
        "could not read password",
        "could not read username",
        "terminal prompts disabled",
        "http 401",
        "unauthorized",
    )
    return any(pattern in lowered for pattern in patterns)


def _get_origin_url(repo_path: Path) -> str | None:
    proc = _run_git(repo_path, ["remote", "get-url", "origin"], capture=True)
    if proc.returncode != 0:
        return None
    url = (proc.stdout or "").strip()
    if not url:
        return None
    logger.debug("remote_url_read", repo=str(repo_path), url=url)
    return url


def _set_repo_mtime_to_latest_commit(repo_path: Path) -> None:
    stats = refresh_repository_tree(repo_path)
    logger.info(
        "repo_timestamps_updated",
        repo_root=str(repo_path),
        files=stats.files_updated,
        directories=stats.directories_updated,
        worktrees=stats.worktrees_scanned,
    )


def _set_origin_url(
    repo_path: Path,
    new_url: str,
    *,
    dry_run: bool,
    old_url: str | None = None,
) -> bool:
    if dry_run:
        logger.info(
            "remote_url_update",
            repo=str(repo_path),
            old=old_url,
            new=new_url,
            dry_run=True,
        )
        return True

    proc = _run_git(repo_path, ["remote", "set-url", "origin", new_url], capture=True)
    ok = proc.returncode == 0
    logger.info(
        "remote_url_update",
        repo=str(repo_path),
        old=old_url,
        new=new_url,
        ok=ok,
        code=proc.returncode,
    )
    return ok


def _extract_url(text: str) -> str | None:
    match = _URL_RE.search(text)
    if match:
        return match.group("url")

    match = _SCP_URL_RE.search(text)
    if match:
        return match.group("url")

    return None


def _detect_moved_url(fetch_output: str) -> str | None:
    lowered = fetch_output.lower()
    moved_markers = (
        "redirecting to",
        "redirected to",
        "moved permanently",
        "repository moved",
        "has moved",
        "moved to",
        "please use",
    )
    if not any(marker in lowered for marker in moved_markers):
        return None
    return _extract_url(fetch_output)


def _slug_from_url(url: str) -> str | None:
    cleaned = url.strip().strip("'\"")
    if not cleaned:
        return None

    parsed = urlparse(cleaned)
    if parsed.scheme and parsed.path:
        tail = parsed.path.rstrip("/").split("/")[-1]
    else:
        scp_match = re.match(r"^(?:[^@\s]+@)?[^:\s]+:(?P<path>.+)$", cleaned)
        if scp_match:
            path_part = scp_match.group("path")
            tail = path_part.rstrip("/").split("/")[-1]
        else:
            tail = cleaned.rstrip("/").split("/")[-1]

    tail = tail.removesuffix(".git")
    return tail or None


def _host_from_url(url: str | None) -> str | None:
    if not url:
        return None
    cleaned = url.strip().strip("'\"")
    if not cleaned:
        return None

    parsed = urlparse(cleaned)
    if parsed.scheme:
        return parsed.hostname.lower() if parsed.hostname else None

    scp_match = re.match(r"^(?:[^@\s]+@)?(?P<host>[^:\s]+):.+$", cleaned)
    if scp_match:
        return scp_match.group("host").lower()

    return None


def _sanitize_worktree_name(ref_name: str) -> str:
    return ref_name.strip().replace("/", "-")


def is_pull_request_tag(tag: str) -> bool:
    return "-PR-" in tag


def _get_current_branch(repo_path: Path) -> str | None:
    proc = _run_git(
        repo_path, ["symbolic-ref", "--quiet", "--short", "HEAD"], capture=True
    )
    if proc.returncode != 0:
        return None
    branch = (proc.stdout or "").strip()
    return branch or None


def _get_git_common_dir(repo_path: Path) -> Path | None:
    proc = _run_git(
        repo_path,
        ["rev-parse", "--path-format=absolute", "--git-common-dir"],
        capture=True,
    )
    if proc.returncode != 0:
        return None
    raw = (proc.stdout or "").strip()
    return Path(raw) if raw else None


def _list_remote_branches(repo_path: Path) -> list[str]:
    proc = _run_git(
        repo_path,
        ["for-each-ref", "--format=%(refname:lstrip=3)", "refs/remotes/origin"],
        capture=True,
    )
    if proc.returncode != 0:
        return []

    branches = []
    for line in proc.stdout.splitlines():
        branch = line.strip()
        if branch and branch != "HEAD":
            branches.append(branch)
    return sorted(set(branches))


def _list_tags(repo_path: Path) -> list[str]:
    proc = _run_git(
        repo_path,
        ["for-each-ref", "--format=%(refname:lstrip=2)", "refs/tags"],
        capture=True,
    )
    if proc.returncode != 0:
        return []

    tags = []
    for line in proc.stdout.splitlines():
        tag = line.strip()
        if tag and not is_pull_request_tag(tag):
            tags.append(tag)
    return sorted(set(tags))


def _local_branch_exists(repo_path: Path, branch: str) -> bool:
    proc = _run_git(
        repo_path, ["show-ref", "--verify", "--quiet", f"refs/heads/{branch}"]
    )
    return proc.returncode == 0


def _worktree_is_dirty(repo_path: Path) -> bool:
    proc = _run_git(repo_path, ["status", "--porcelain"], capture=True)
    if proc.returncode != 0:
        return True
    return bool((proc.stdout or "").strip())


def _list_worktree_paths(repo_path: Path) -> set[Path]:
    proc = _run_git(repo_path, ["worktree", "list", "--porcelain"], capture=True)
    if proc.returncode != 0:
        return set()

    paths: set[Path] = set()
    for line in proc.stdout.splitlines():
        if line.startswith("worktree "):
            paths.add(Path(line.removeprefix("worktree ").strip()))
    return paths


def _get_worktree_layout_roots(repo_path: Path) -> tuple[Path, Path] | None:
    common_dir = _get_git_common_dir(repo_path)
    if common_dir is None or common_dir.name != WORKTREE_GIT_DIR_NAME:
        return None
    repo_root = common_dir.parent
    return repo_root, repo_root


def _worktree_project_root(path: Path) -> Path | None:
    for current in (path, *path.parents):
        if (current / WORKTREE_GIT_DIR_NAME).is_dir():
            return current
    return None


def _iter_repos(project: Path) -> Iterator[Path]:
    repos: set[Path] = set()
    pruned_dirs = {".git", WORKTREE_GIT_DIR_NAME}
    for root, dirnames, filenames in os.walk(project, topdown=True):
        root_path = Path(root)
        if WORKTREE_GIT_DIR_NAME in dirnames:
            git_dir = root_path / WORKTREE_GIT_DIR_NAME
            repo_root = git_dir.parent
            trunk = repo_root / TRUNK_DIR_NAME
            repo = trunk if trunk.is_dir() else git_dir
            if repo not in repos:
                repos.add(repo)
                yield repo

        if ".git" in dirnames or ".git" in filenames:
            repo = root_path
            if _worktree_project_root(repo) is None and repo not in repos:
                repos.add(repo)
                yield repo

        dirnames[:] = [name for name in dirnames if name not in pruned_dirs]


def _discover_repos(project: Path) -> list[Path]:
    return sorted(_iter_repos(project), key=lambda path: str(path).casefold())


def _is_bitbucket_repo(repo_path: Path) -> bool:
    return _host_from_url(_get_origin_url(repo_path)) == BITBUCKET_HOST


def _safe_rename_repo_folder(
    repo_path: Path,
    new_slug: str,
    old_slug: str | None,
    *,
    rename_on_move: bool,
    dry_run: bool,
) -> Path:
    if (
        not rename_on_move
        or not old_slug
        or repo_path.name != old_slug
        or repo_path.name == new_slug
    ):
        return repo_path

    target = repo_path.with_name(new_slug)
    if target.exists():
        logger.warning(
            "repo_move",
            repo=str(repo_path),
            target=str(target),
            ok=False,
            reason="target_exists",
        )
        return repo_path

    if dry_run:
        logger.info(
            "repo_move", repo=str(repo_path), target=str(target), ok=True, dry_run=True
        )
        return target

    shutil.move(str(repo_path), str(target))
    logger.info("repo_move", repo=str(repo_path), target=str(target), ok=True)
    return target


def _is_missing_remote(fetch_output: str) -> bool:
    lowered = fetch_output.lower()
    patterns = (
        "repository not found",
        "not found",
        "does not exist",
        "no such repository",
        "the requested url returned error: 404",
        "error: 404",
        "project not found",
    )
    transient_markers = (
        "timed out",
        "timeout",
        "temporary failure",
        "could not resolve host",
        "connection refused",
        "connection reset",
        "permission denied",
        "authentication failed",
        "host key verification failed",
    )
    if "tf401019" in lowered:
        return True
    if any(marker in lowered for marker in transient_markers):
        return False
    return any(pattern in lowered for pattern in patterns)


def _is_retryable_fetch_error(fetch_output: str) -> bool:
    lowered = fetch_output.lower()
    patterns = (
        "kex_exchange_identification",
        "ssh_exchange_identification",
        "connection reset by peer",
        "connection reset",
        "connection timed out",
        "operation timed out",
        "timeout",
        "temporary failure",
        "could not resolve host",
        "broken pipe",
        "remote end hung up unexpectedly",
        "internal server error",
    )
    return any(pattern in lowered for pattern in patterns)


def _wait_for_bitbucket_slot(interval_seconds: int, *, reason: str) -> None:
    global _LAST_BITBUCKET_CALL_AT
    now = time.perf_counter()
    if _LAST_BITBUCKET_CALL_AT is not None:
        wait_for = interval_seconds - (now - _LAST_BITBUCKET_CALL_AT)
        if wait_for > 0:
            logger.debug(
                "throttle_wait",
                seconds=round(wait_for, 3),
                stream="bitbucket",
                reason=reason,
            )
            time.sleep(wait_for)
    _LAST_BITBUCKET_CALL_AT = time.perf_counter()


def _prune_repo(
    repo_path: Path, *, project: Path, trash_dir: Path, dry_run: bool, reason: str
) -> bool:
    ts = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    dest_root = (
        trash_dir
        if trash_dir != project / DEFAULT_TRASH_DIR_NAME
        else project / DEFAULT_TRASH_DIR_NAME / ts
    )
    if dest_root.name != ts:
        dest_root = dest_root / ts
    dest_root.mkdir(parents=True, exist_ok=True)
    dest = dest_root / repo_path.name

    if dry_run:
        logger.info(
            "repo_prune",
            repo=str(repo_path),
            dest=str(dest),
            reason=reason,
            dry_run=True,
        )
        return True

    try:
        shutil.move(str(repo_path), str(dest))
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "repo_prune",
            repo=str(repo_path),
            dest=str(dest),
            reason=reason,
            error=str(exc),
        )
        return False

    logger.info(
        "repo_prune",
        repo=str(repo_path),
        dest=str(dest),
        reason=reason,
        dry_run=False,
    )
    return True


def _sync_branch_worktrees(
    repo_path: Path,
    *,
    prune_branch_worktrees: bool,
    dry_run: bool,
) -> None:
    layout_roots = _get_worktree_layout_roots(repo_path)
    if layout_roots is None:
        logger.debug(
            "worktree_sync_skip",
            repo=str(repo_path),
            reason="not_branch_worktree_layout",
        )
        return
    branches_root, _ = layout_roots

    common_dir = _get_git_common_dir(repo_path)
    if common_dir is None:
        logger.debug(
            "worktree_sync_skip",
            repo=str(repo_path),
            reason="git_common_dir_unavailable",
        )
        return

    common_dir_key = str(common_dir)
    if common_dir_key in _SYNCED_WORKTREE_COMMON_DIRS:
        logger.debug(
            "worktree_sync_skip",
            repo=str(repo_path),
            reason="already_synced",
            common_dir=common_dir_key,
        )
        return
    _SYNCED_WORKTREE_COMMON_DIRS.add(common_dir_key)

    remote_branches = _list_remote_branches(repo_path)
    if not remote_branches:
        logger.debug(
            "worktree_sync_skip", repo=str(repo_path), reason="no_remote_branches"
        )
        return

    expected_paths: set[Path] = set()
    for branch in remote_branches:
        target = branches_root / _sanitize_worktree_name(branch)
        expected_paths.add(target)

        bind_contextvars(branch=branch, worktree=str(target))
        try:
            if not target.exists():
                if dry_run:
                    logger.info("worktree_branch_add", dry_run=True)
                    continue

                if _local_branch_exists(repo_path, branch):
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

                add_proc = _run_git(repo_path, add_args, capture=True)
                if add_proc.returncode != 0:
                    logger.warning(
                        "worktree_add_failed",
                        output=(add_proc.stdout or "").strip()[-2000:],
                    )
                    continue
                logger.info("worktree_branch_add")

            if not dry_run and ensure_dprint_config_link(target):
                logger.info("dprint_config_link")

            set_upstream = _run_git(
                target,
                ["branch", "--set-upstream-to", f"origin/{branch}", branch],
                capture=True,
            )
            if set_upstream.returncode != 0:
                logger.warning(
                    "worktree_branch_set_upstream_failed",
                    error=(set_upstream.stdout or "").strip(),
                )

            if _worktree_is_dirty(target):
                logger.warning(
                    "worktree_branch_dirty_skip",
                    reason="local changes detected; skipping update to avoid data loss",
                )
                continue

            if dry_run:
                logger.info("worktree_branch_update", dry_run=True)
                continue

            ff_only_proc = _run_git(
                target, ["merge", "--ff-only", f"origin/{branch}"], capture=True
            )
            if ff_only_proc.returncode != 0:
                logger.warning(
                    "worktree_branch_update_skipped",
                    reason=(
                        ff_only_proc.stdout
                        or "non-fast-forward; leaving local branch unchanged"
                    ).strip(),
                )
                continue

            logger.info("worktree_branch_update")
        finally:
            unbind_contextvars("branch", "worktree")

    if not prune_branch_worktrees:
        return

    existing_worktrees = _list_worktree_paths(repo_path)
    for worktree_path in sorted(existing_worktrees):
        if worktree_path in expected_paths or worktree_path == repo_path:
            continue
        if not worktree_path.is_relative_to(branches_root):
            continue

        bind_contextvars(worktree=str(worktree_path))
        try:
            if _worktree_is_dirty(worktree_path):
                logger.warning(
                    "worktree_prune_dirty_skip",
                    reason="local changes detected; skipping prune to avoid data loss",
                )
                continue

            if dry_run:
                logger.info("worktree_pruned", dry_run=True)
                continue

            remove_proc = _run_git(
                repo_path, ["worktree", "remove", str(worktree_path)], capture=True
            )
            if remove_proc.returncode == 0:
                logger.info("worktree_pruned")
        finally:
            unbind_contextvars("worktree")

    if not dry_run:
        _run_git(repo_path, ["worktree", "prune"])


def _sync_tag_worktrees(
    repo_path: Path,
    *,
    prune_tag_worktrees: bool,
    dry_run: bool,
) -> None:
    layout_roots = _get_worktree_layout_roots(repo_path)
    if layout_roots is None:
        logger.debug(
            "worktree_sync_skip",
            repo=str(repo_path),
            reason="not_branch_worktree_layout",
        )
        return
    _, tags_root = layout_roots

    common_dir = _get_git_common_dir(repo_path)
    if common_dir is None:
        logger.debug(
            "worktree_sync_skip",
            repo=str(repo_path),
            reason="git_common_dir_unavailable",
        )
        return

    common_dir_key = f"{common_dir}::tags"
    if common_dir_key in _SYNCED_WORKTREE_COMMON_DIRS:
        logger.debug(
            "worktree_sync_skip",
            repo=str(repo_path),
            reason="already_synced_tags",
            common_dir=common_dir_key,
        )
        return
    _SYNCED_WORKTREE_COMMON_DIRS.add(common_dir_key)

    remote_tags = _list_tags(repo_path)
    if not remote_tags:
        logger.debug("worktree_sync_skip", repo=str(repo_path), reason="no_tags")
        return

    tags_root.mkdir(parents=True, exist_ok=True)
    expected_paths: set[Path] = set()
    for tag in remote_tags:
        target = tags_root / _sanitize_worktree_name(tag)
        expected_paths.add(target)

        bind_contextvars(tag=tag, worktree=str(target))
        try:
            if target.name in {WORKTREE_GIT_DIR_NAME, TRUNK_DIR_NAME, ".git"}:
                logger.warning("worktree_tag_skipped", reason="reserved_path")
                continue
            if target.exists():
                if not (target / ".git").exists():
                    logger.warning("worktree_tag_skipped", reason="path_exists")
                elif not dry_run and ensure_dprint_config_link(target):
                    logger.info("dprint_config_link")
                continue

            if dry_run:
                logger.info("worktree_tag_add", dry_run=True)
                continue

            add_proc = _run_git(
                repo_path,
                ["worktree", "add", "--detach", str(target), tag],
                capture=True,
            )
            if add_proc.returncode != 0:
                logger.warning(
                    "worktree_tag_add_failed",
                    output=(add_proc.stdout or "").strip()[-2000:],
                )
                continue
            logger.info("worktree_tag_add")
            if ensure_dprint_config_link(target):
                logger.info("dprint_config_link")
        finally:
            unbind_contextvars("tag", "worktree")

    if not prune_tag_worktrees:
        return

    existing_worktrees = _list_worktree_paths(repo_path)
    for worktree_path in sorted(existing_worktrees):
        if worktree_path in expected_paths or worktree_path == repo_path:
            continue
        if is_pull_request_tag(worktree_path.name):
            continue
        if worktree_path.name == WORKTREE_GIT_DIR_NAME:
            continue
        if not worktree_path.is_relative_to(tags_root):
            continue
        if _get_current_branch(worktree_path):
            continue

        bind_contextvars(worktree=str(worktree_path))
        try:
            if _worktree_is_dirty(worktree_path):
                logger.warning(
                    "worktree_tag_prune_dirty_skip",
                    reason="local changes detected; skipping prune to avoid data loss",
                )
                continue

            if dry_run:
                logger.info("worktree_tag_pruned", dry_run=True)
                continue

            remove_proc = _run_git(
                repo_path, ["worktree", "remove", str(worktree_path)], capture=True
            )
            if remove_proc.returncode == 0:
                logger.info("worktree_tag_pruned")
        finally:
            unbind_contextvars("worktree")

    if not dry_run:
        _run_git(repo_path, ["worktree", "prune"])


def fetch_repo(
    repo_path: Path,
    *,
    bitbucket_interval_seconds: int,
    bitbucket_timeout_seconds: float,
    azure_pat: str | None,
    fix_moved: bool,
    rename_on_move: bool,
    prune_missing: bool,
    sync_branch_worktrees: bool,
    prune_branch_worktrees: bool,
    sync_tag_worktrees: bool,
    prune_tag_worktrees: bool,
    project: Path,
    trash_dir: Path,
    dry_run: bool,
) -> tuple[bool, bool, float, int, bool]:
    start = time.perf_counter()
    origin_url = _get_origin_url(repo_path)
    old_slug = _slug_from_url(origin_url) if origin_url else None
    attempt_counter = 0
    is_bitbucket_repo = _host_from_url(origin_url) == BITBUCKET_HOST
    is_azure_repo = _host_from_url(origin_url) in AZURE_GIT_HOSTS
    use_azure_pat = (
        _host_from_url(origin_url) == "dev.azure.com" and azure_pat is not None
    )
    fetch_timeout = (
        bitbucket_timeout_seconds
        if is_bitbucket_repo
        else DEFAULT_AZURE_TIMEOUT_SECONDS
        if is_azure_repo
        else None
    )
    deadline = start + fetch_timeout if fetch_timeout is not None else None

    def _git_env() -> dict[str, str] | None:
        if use_azure_pat:
            return _azure_git_env(origin_url, azure_pat)
        return _azure_git_helper_env(origin_url)

    @stamina.retry(
        on=RetryableFetchError,
        attempts=3,
        timeout=fetch_timeout,
    )
    def _attempt_fetch() -> tuple[bool, bool, int, str]:
        nonlocal attempt_counter, use_azure_pat
        attempt_counter += 1
        if is_bitbucket_repo:
            _wait_for_bitbucket_slot(
                bitbucket_interval_seconds,
                reason="bitbucket_call" if attempt_counter == 1 else "bitbucket_retry",
            )
        logger.debug("fetch_start", attempt=attempt_counter)
        try:
            dry = _run_git(
                repo_path,
                ["fetch", "--all", "--tags", "--dry-run", "--verbose"],
                capture=True,
                timeout=_remaining_timeout(deadline),
                env=_git_env(),
            )
        except subprocess.TimeoutExpired as exc:
            output = _format_timeout_output(
                exc, fetch_timeout or bitbucket_timeout_seconds
            )
            return False, False, output.count("\n") + 1, output
        output = dry.stdout or ""
        updated = bool(output.strip()) and dry.returncode == 0
        line_count = output.count("\n") + (
            1 if output and not output.endswith("\n") else 0
        )
        if dry.returncode != 0 and use_azure_pat and _is_azure_auth_error(output):
            use_azure_pat = False
            logger.info("fetch_retry", reason="azure_pat_rejected_using_git_helper")
            return _attempt_fetch()
        if dry.returncode != 0 and _is_retryable_fetch_error(output):
            logger.info(
                "fetch_retry",
                reason="transient_fetch_error",
                attempt=attempt_counter,
            )
            raise RetryableFetchError(output, line_count)
        return (dry.returncode == 0), updated, line_count, output

    try:
        ok, updated, line_count, output = _attempt_fetch()
    except RetryableFetchError as exc:
        ok, updated, line_count, output = False, False, exc.line_count, exc.output
    if ok and not dry_run:
        if is_bitbucket_repo:
            _wait_for_bitbucket_slot(
                bitbucket_interval_seconds,
                reason="bitbucket_fetch",
            )
        try:
            proc = _run_git(
                repo_path,
                ["fetch", "--all", "--tags", "--quiet"],
                timeout=_remaining_timeout(deadline),
                env=_git_env(),
            )
        except subprocess.TimeoutExpired as exc:
            ok = False
            output = _format_timeout_output(
                exc, fetch_timeout or bitbucket_timeout_seconds
            )
        else:
            if proc.returncode != 0:
                ok = False
                output = (
                    output + "\n" + f"fetch_quiet_failed code={proc.returncode}"
                ).strip()

    if not ok and fix_moved:
        moved_url = _detect_moved_url(output)
        if moved_url and moved_url != origin_url:
            _set_origin_url(repo_path, moved_url, dry_run=dry_run, old_url=origin_url)
            new_slug = _slug_from_url(moved_url)
            if new_slug:
                repo_path = _safe_rename_repo_folder(
                    repo_path,
                    new_slug,
                    old_slug,
                    rename_on_move=rename_on_move,
                    dry_run=dry_run,
                )
            logger.info("fetch_retry", reason="moved_remote", new_url=moved_url)
            origin_url = moved_url
            attempt_counter = 1
            try:
                ok, updated, line_count, output = _attempt_fetch()
            except RetryableFetchError as exc:
                ok, updated, line_count, output = (
                    False,
                    False,
                    exc.line_count,
                    exc.output,
                )
            if ok and not dry_run:
                if is_bitbucket_repo:
                    _wait_for_bitbucket_slot(
                        bitbucket_interval_seconds,
                        reason="bitbucket_fetch",
                    )
                try:
                    proc = _run_git(
                        repo_path,
                        ["fetch", "--all", "--tags", "--quiet"],
                        timeout=_remaining_timeout(deadline),
                        env=_git_env(),
                    )
                except subprocess.TimeoutExpired as exc:
                    ok = False
                    output = _format_timeout_output(
                        exc, fetch_timeout or bitbucket_timeout_seconds
                    )
                else:
                    if proc.returncode != 0:
                        ok = False
                        output = (
                            output + "\n" + f"fetch_quiet_failed code={proc.returncode}"
                        ).strip()

    dur = round(time.perf_counter() - start, 3)
    if ok:
        if not dry_run and ensure_dprint_config_link(repo_path):
            logger.info("dprint_config_link")
        if sync_branch_worktrees:
            _sync_branch_worktrees(
                repo_path,
                prune_branch_worktrees=prune_branch_worktrees,
                dry_run=dry_run,
            )
        if sync_tag_worktrees:
            _sync_tag_worktrees(
                repo_path,
                prune_tag_worktrees=prune_tag_worktrees,
                dry_run=dry_run,
            )
        logger.info("fetch_result", updated=updated, dur_s=dur, lines=line_count)
        return True, updated, dur, line_count, False

    if prune_missing and _is_missing_remote(output):
        pruned = _prune_repo(
            repo_path,
            project=project,
            trash_dir=trash_dir,
            dry_run=dry_run,
            reason="missing_remote",
        )
        if pruned:
            return False, False, dur, 0, True

    if _is_missing_remote(output):
        logger.warning(
            "repo_skipped",
            reason="remote_missing_or_forbidden",
            origin=origin_url,
            output=output[-2000:] if output else "",
        )
        return False, False, dur, 0, True

    logger.warning(
        "fetch_error",
        dur_s=dur,
        origin=origin_url,
        output=output[-2000:] if output else "",
    )
    return False, False, dur, 0, False


def _process_one_repo(
    repo: Path,
    *,
    stream: str,
    totals: dict[str, int],
    total_repos: int | None,
    bitbucket_interval_seconds: int,
    bitbucket_timeout_seconds: float,
    azure_pat: str | None,
    fix_moved: bool,
    rename_on_move: bool,
    prune_missing: bool,
    sync_branch_worktrees: bool,
    prune_branch_worktrees: bool,
    sync_tag_worktrees: bool,
    prune_tag_worktrees: bool,
    project: Path,
    trash_dir: Path,
    dry_run: bool,
    totals_lock: Lock | None = None,
) -> None:
    if totals_lock is None:
        totals_lock = Lock()
    bind_contextvars(repo=str(repo), stream=stream, project=str(project))
    try:
        if not repo.is_dir():
            with totals_lock:
                totals["skipped"] += 1
            logger.warning("repo_skipped", reason="local_path_missing")
            return

        ok, updated, dur, lines, skipped = fetch_repo(
            repo,
            bitbucket_interval_seconds=bitbucket_interval_seconds,
            bitbucket_timeout_seconds=bitbucket_timeout_seconds,
            azure_pat=azure_pat,
            fix_moved=fix_moved,
            rename_on_move=rename_on_move,
            prune_missing=prune_missing,
            sync_branch_worktrees=sync_branch_worktrees,
            prune_branch_worktrees=prune_branch_worktrees,
            sync_tag_worktrees=True,
            prune_tag_worktrees=prune_tag_worktrees,
            project=project,
            trash_dir=trash_dir,
            dry_run=dry_run,
        )
        if ok and not dry_run:
            _set_repo_mtime_to_latest_commit(repo)

        with totals_lock:
            totals["processed"] += 1
            if skipped:
                totals["skipped"] += 1
            elif ok:
                totals["success"] += 1
                totals["lines"] += lines
                if updated:
                    totals["updated"] += 1
            else:
                totals["failed"] += 1

            processed = totals["processed"]
            should_log = processed % 10 == 0 or (
                total_repos is not None and processed == total_repos
            )
            progress_snapshot = {
                "processed": processed,
                "total": total_repos if total_repos is not None else "streaming",
                "success": totals["success"],
                "failed": totals["failed"],
                "skipped": totals["skipped"],
                "updated": totals["updated"],
            }

        if ok and updated:
            logger.info("update", fetch_dur_s=dur)

        if should_log:
            logger.info("progress", **progress_snapshot)
    finally:
        clear_contextvars()


def main(
    project: Path,
    *,
    bitbucket_interval_seconds: int,
    bitbucket_timeout_seconds: float,
    fix_moved: bool,
    rename_on_move: bool,
    prune_missing: bool,
    sync_branch_worktrees: bool,
    prune_branch_worktrees: bool,
    sync_tag_worktrees: bool,
    prune_tag_worktrees: bool,
    trash_dir: Path,
    dry_run: bool,
) -> None:
    start_time = time.perf_counter()
    scan_start = time.perf_counter()
    logger.info("scan_start", project=str(project))
    azure_pat = _load_azure_pat()
    logger.info(
        "start",
        repo_count=None,
        bitbucket_count=None,
        other_count=None,
        bitbucket_interval=bitbucket_interval_seconds,
        bitbucket_timeout=bitbucket_timeout_seconds,
        azure_pat_loaded=azure_pat is not None,
        other_interval=0,
        streaming=True,
        interlaced=True,
        fetch_streams=2,
        sync_branch_worktrees=sync_branch_worktrees,
        prune_branch_worktrees=prune_branch_worktrees,
        sync_tag_worktrees=sync_tag_worktrees,
        prune_tag_worktrees=prune_tag_worktrees,
        dry_run=dry_run,
    )

    totals = {
        "processed": 0,
        "success": 0,
        "failed": 0,
        "skipped": 0,
        "updated": 0,
        "lines": 0,
    }
    # Keep discovery independent from both fetch streams. The Bitbucket worker
    # remains single-threaded so its network-call throttle stays global.
    bitbucket_queue: Queue[Path | None] = Queue()
    other_queue: Queue[Path | None] = Queue()
    totals_lock = Lock()
    discovered_count = 0
    existing_count = 0
    bitbucket_count = 0
    other_count = 0

    def discover_repos() -> None:
        nonlocal bitbucket_count, discovered_count, existing_count, other_count

        try:
            for repo in repo_iterator:
                discovered_count += 1
                if not repo.is_dir():
                    logger.warning(
                        "repo_skipped", repo=str(repo), reason="local_path_missing"
                    )
                    continue

                existing_count += 1
                if _is_bitbucket_repo(repo):
                    bitbucket_count += 1
                    bitbucket_queue.put(repo)
                else:
                    other_count += 1
                    other_queue.put(repo)
            logger.info(
                "scan_done",
                discovered_count=discovered_count,
                existing_count=existing_count,
                bitbucket_count=bitbucket_count,
                other_count=other_count,
                dur_s=round(time.perf_counter() - scan_start, 3),
            )
        finally:
            bitbucket_queue.put(None)
            other_queue.put(None)

    def process_repo_queue(queue: Queue[Path | None], *, stream: str) -> None:
        while True:
            repo = queue.get()
            try:
                if repo is None:
                    return
                _process_one_repo(
                    repo,
                    stream=stream,
                    totals=totals,
                    total_repos=None,
                    bitbucket_interval_seconds=bitbucket_interval_seconds,
                    bitbucket_timeout_seconds=bitbucket_timeout_seconds,
                    azure_pat=azure_pat,
                    fix_moved=fix_moved,
                    rename_on_move=rename_on_move,
                    prune_missing=prune_missing,
                    sync_branch_worktrees=sync_branch_worktrees,
                    prune_branch_worktrees=prune_branch_worktrees,
                    sync_tag_worktrees=sync_tag_worktrees,
                    prune_tag_worktrees=prune_tag_worktrees,
                    project=project,
                    trash_dir=trash_dir,
                    dry_run=dry_run,
                    totals_lock=totals_lock,
                )
            finally:
                queue.task_done()

    repo_iterator = iter(_iter_repos(project))

    with ThreadPoolExecutor(
        max_workers=3, thread_name_prefix="repo-update"
    ) as executor:
        futures = [
            executor.submit(discover_repos),
            executor.submit(process_repo_queue, bitbucket_queue, stream="bitbucket"),
            executor.submit(process_repo_queue, other_queue, stream="other"),
        ]
        for future in futures:
            future.result()

    if existing_count == 0:
        logger.info("no_repos", project=str(project))
        return

    duration = round(time.perf_counter() - start_time, 2)
    logger.info(
        "done",
        processed=totals["processed"],
        fetched=totals["success"],
        failed=totals["failed"],
        skipped=totals["skipped"],
        updated=totals["updated"],
        dur_s=duration,
        lines=totals["lines"],
    )


@click.group(
    cls=RustGroup,
    invoke_without_command=True,
    context_settings={"help_option_names": ["-h", "--help"]},
    help="Fast git fetcher with optional worktree sync.",
    epilog=(
        "update_all_local_repos.py update\nupdate_all_local_repos.py update --prune-missing\nupdate_all_local_repos.py update --prune-tag-worktrees\nupdate_all_local_repos.py update --project ~/users --dry-run -vv"
    ),
)
@click.option(
    "--color",
    type=click.Choice(["auto", "always", "never"], case_sensitive=False),
    default="auto",
    expose_value=False,
    callback=_apply_color_option,
    help="Control when colored output is used",
)
@click.version_option(__version__, "-V", "--version")
@click.pass_context
def cli(ctx: click.Context) -> None:
    if ctx.invoked_subcommand is None:
        click.echo(ctx.get_help(), nl=False, color=True)


@cli.command(
    "help", short_help="Print this message or the help of the given subcommand."
)
@click.argument("command", required=False)
@click.pass_context
def help_command(ctx: click.Context, command: str | None) -> None:
    if not command:
        click.echo(ctx.parent.get_help(), nl=False, color=True)
        return

    cmd = ctx.parent.command.get_command(ctx.parent, command)
    if cmd is None:
        raise click.UsageError(f"Unknown command: {command}")

    child_ctx = click.Context(cmd, info_name=command, parent=ctx.parent)
    click.echo(cmd.get_help(child_ctx), nl=False, color=True)


@cli.command("check", short_help="Check Git and the local repository root.")
@click.option(
    "--project",
    "-p",
    type=click.Path(path_type=Path, file_okay=False),
    default=DEFAULT_PROJECT,
    show_default=True,
)
def check_command(project: Path) -> None:
    """Check required local setup without fetching repositories."""
    errors: list[str] = []
    if shutil.which("git") is None:
        errors.append("missing executable: git")
    if not project.expanduser().is_dir():
        errors.append(f"missing directory: {project.expanduser()}")
    if errors:
        for error in errors:
            click.echo(error, err=True)
        raise SystemExit(1)
    click.echo("OK")


@cli.command("update", short_help="Fetch repos and reconcile remotes/worktrees.")
@click.option(
    "--project",
    "-p",
    type=click.Path(path_type=Path),
    default=DEFAULT_PROJECT,
    show_default=str(DEFAULT_PROJECT),
    help="Root directory to scan for Git repositories",
)
@click.option(
    "--bitbucket-throttle-delay",
    "--bitbucket-interval",
    "bitbucket_interval_seconds",
    type=click.IntRange(min=0),
    default=DEFAULT_BITBUCKET_INTERVAL_SECONDS,
    show_default=True,
    help=(
        "Minimum throttling delay between Bitbucket fetch/retry starts; not the timeout"
    ),
)
@click.option(
    "--bitbucket-timeout",
    "bitbucket_timeout_seconds",
    type=click.FloatRange(min=0.1),
    default=DEFAULT_BITBUCKET_TIMEOUT_SECONDS,
    show_default=True,
    help="Maximum total seconds for each Bitbucket fetch, including pull time",
)
@click.option(
    "--fix-moved/--no-fix-moved",
    default=True,
    show_default=True,
    help="Update origin when the remote indicates a moved repository",
)
@click.option(
    "--rename-on-move/--no-rename-on-move",
    default=True,
    show_default=True,
    help="Rename the local repository folder when a moved remote implies a new slug",
)
@click.option(
    "--prune-missing/--no-prune-missing",
    default=False,
    show_default=True,
    help="Move repositories with missing remotes into the trash directory",
)
@click.option(
    "--sync-branch-worktrees/--no-sync-branch-worktrees",
    default=False,
    show_default=True,
    help="Deprecated legacy branch-worktree sync; normal updates manage only trunk and tags",
)
@click.option(
    "--prune-branch-worktrees/--no-prune-branch-worktrees",
    default=False,
    show_default=True,
    help="Deprecated legacy branch-worktree prune",
)
@click.option(
    "--sync-tag-worktrees/--no-sync-tag-worktrees",
    default=True,
    show_default=True,
    help="Sync detached top-level tag worktrees",
)
@click.option(
    "--prune-tag-worktrees/--no-prune-tag-worktrees",
    default=False,
    show_default=True,
    help="Remove stale detached tag worktrees that no longer exist locally as tags",
)
@click.option(
    "--trash-dir",
    type=click.Path(path_type=Path),
    help="Directory where pruned repositories are moved",
)
@click.option(
    "--dry-run",
    is_flag=True,
    help="Log intended changes without mutating anything",
)
@click.option(
    "--verbose",
    "-v",
    count=True,
    help="Increase log verbosity; use -vv for debug traces",
)
def update(
    project: Path,
    bitbucket_interval_seconds: int,
    bitbucket_timeout_seconds: float,
    fix_moved: bool,
    rename_on_move: bool,
    prune_missing: bool,
    sync_branch_worktrees: bool,
    prune_branch_worktrees: bool,
    sync_tag_worktrees: bool,
    prune_tag_worktrees: bool,
    trash_dir: Path | None,
    dry_run: bool,
    verbose: int,
) -> None:
    """Fetch repos and reconcile moved remotes and tag worktrees."""
    configure_logging(verbose)
    resolved_project = project.expanduser()
    resolved_trash = (
        trash_dir.expanduser()
        if trash_dir
        else resolved_project / DEFAULT_TRASH_DIR_NAME
    )

    bind_contextvars(project=str(resolved_project))
    try:
        main(
            resolved_project,
            bitbucket_interval_seconds=bitbucket_interval_seconds,
            bitbucket_timeout_seconds=bitbucket_timeout_seconds,
            fix_moved=fix_moved,
            rename_on_move=rename_on_move,
            prune_missing=prune_missing,
            sync_branch_worktrees=sync_branch_worktrees,
            prune_branch_worktrees=prune_branch_worktrees,
            sync_tag_worktrees=sync_tag_worktrees,
            prune_tag_worktrees=prune_tag_worktrees,
            trash_dir=resolved_trash,
            dry_run=dry_run,
        )
    finally:
        clear_contextvars()


class TestUpdateAllLocalRepos(unittest.TestCase):
    @staticmethod
    def _fetch_options(**overrides: object) -> dict[str, object]:
        options: dict[str, object] = {
            "bitbucket_interval_seconds": 0,
            "bitbucket_timeout_seconds": DEFAULT_BITBUCKET_TIMEOUT_SECONDS,
            "azure_pat": None,
            "fix_moved": False,
            "rename_on_move": False,
            "prune_missing": False,
            "sync_branch_worktrees": False,
            "prune_branch_worktrees": False,
            "sync_tag_worktrees": False,
            "prune_tag_worktrees": False,
            "project": Path(),
            "trash_dir": Path(".trash"),
            "dry_run": True,
        }
        options.update(overrides)
        return options

    def test_update_separates_bitbucket_interval_from_timeout(self) -> None:
        runner = CliRunner()
        with patch(f"{__name__}.main") as mocked_main:
            result = runner.invoke(
                cli,
                ["update", "--project", str(Path.cwd())],
            )

        assert result.exit_code == 0, result.output
        options = mocked_main.call_args.kwargs
        assert options["bitbucket_interval_seconds"] == 6
        assert options["bitbucket_timeout_seconds"] == 30.0

    def test_update_documents_bitbucket_throttling(self) -> None:
        result = CliRunner().invoke(cli, ["update", "--help"])

        assert result.exit_code == 0, result.output
        assert "--bitbucket-throttle-delay" in result.output
        assert "--bitbucket-interval" in result.output
        assert "throttling delay" in result.output
        assert "not the timeout" in result.output

    def test_repo_mtime_uses_latest_commit_timestamp(self) -> None:
        with TemporaryDirectory() as directory:
            project = Path(directory) / "repo"
            trunk = project / TRUNK_DIR_NAME
            trunk.mkdir(parents=True)
            (project / WORKTREE_GIT_DIR_NAME).mkdir()
            with patch(f"{__name__}.refresh_repository_tree") as refresh_mock:
                _set_repo_mtime_to_latest_commit(trunk)

            refresh_mock.assert_called_once_with(trunk)

    def test_refresh_repository_tree_uses_file_commit_times(self) -> None:
        with TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()

            def run_test_git(*args: str, env: dict[str, str] | None = None) -> None:
                subprocess.run(  # noqa: S603, S607
                    ["git", "-C", str(repo), *args],  # noqa: S607
                    check=True,
                    env=env,
                )

            run_test_git("init", "-q")
            run_test_git("config", "user.email", "test@example.com")
            run_test_git("config", "user.name", "Test")

            old_timestamp = 1_577_836_800
            new_timestamp = 1_672_531_200
            old_file = repo / "old.txt"
            old_file.write_text("old\n", encoding="utf-8")
            commit_env = os.environ | {
                "GIT_AUTHOR_DATE": str(old_timestamp),
                "GIT_COMMITTER_DATE": str(old_timestamp),
            }
            run_test_git("add", "old.txt")
            run_test_git(
                "-c",
                "core.hooksPath=/dev/null",
                "commit",
                "-q",
                "-m",
                "old",
                env=commit_env,
            )

            nested = repo / "nested"
            nested.mkdir()
            new_file = nested / "new.txt"
            new_file.write_text("new\n", encoding="utf-8")
            commit_env.update(
                GIT_AUTHOR_DATE=str(new_timestamp),
                GIT_COMMITTER_DATE=str(new_timestamp),
            )
            run_test_git("add", "nested/new.txt")
            run_test_git(
                "-c",
                "core.hooksPath=/dev/null",
                "commit",
                "-q",
                "-m",
                "new",
                env=commit_env,
            )

            dirty_timestamp = new_timestamp + 123
            new_file.write_text("new dirty\n", encoding="utf-8")
            os.utime(
                new_file,
                ns=(dirty_timestamp * 1_000_000_000, dirty_timestamp * 1_000_000_000),
            )
            untracked_timestamp = dirty_timestamp - 10
            untracked_file = repo / "untracked.txt"
            untracked_file.write_text("untracked\n", encoding="utf-8")
            os.utime(
                untracked_file,
                ns=(
                    untracked_timestamp * 1_000_000_000,
                    untracked_timestamp * 1_000_000_000,
                ),
            )
            symlink_target = repo / "ruff-target.toml"
            symlink_target.write_text("target\n", encoding="utf-8")
            os.utime(
                symlink_target,
                ns=(
                    untracked_timestamp * 1_000_000_000,
                    untracked_timestamp * 1_000_000_000,
                ),
            )
            symlink_timestamp = dirty_timestamp + 1_000
            symlink = repo / "ruff.toml"
            symlink.symlink_to(symlink_target.name)
            os.utime(
                symlink,
                ns=(
                    symlink_timestamp * 1_000_000_000,
                    symlink_timestamp * 1_000_000_000,
                ),
                follow_symlinks=False,
            )
            git_timestamp = dirty_timestamp + 2_000
            gitignore = repo / ".gitignore"
            gitignore.write_text(".venv/\n", encoding="utf-8")
            os.utime(
                gitignore,
                ns=(
                    untracked_timestamp * 1_000_000_000,
                    untracked_timestamp * 1_000_000_000,
                ),
            )
            ignored_directory = repo / ".venv"
            ignored_directory.mkdir()
            ignored_file = ignored_directory / "ignored.txt"
            ignored_file.write_text("ignored\n", encoding="utf-8")
            ignored_timestamp = git_timestamp + 1_000
            os.utime(
                ignored_file,
                ns=(
                    ignored_timestamp * 1_000_000_000,
                    ignored_timestamp * 1_000_000_000,
                ),
            )
            os.utime(
                ignored_directory,
                ns=(
                    ignored_timestamp * 1_000_000_000,
                    ignored_timestamp * 1_000_000_000,
                ),
            )
            os.utime(
                repo / ".git",
                ns=(git_timestamp * 1_000_000_000, git_timestamp * 1_000_000_000),
            )
            stats = refresh_repository_tree(repo)

            assert stats.files_updated == 1
            assert old_file.stat().st_mtime == old_timestamp
            assert new_file.stat().st_mtime == dirty_timestamp
            assert untracked_file.stat().st_mtime == untracked_timestamp
            assert symlink.stat(follow_symlinks=False).st_mtime == symlink_timestamp
            assert ignored_file.stat().st_mtime == ignored_timestamp
            assert ignored_directory.stat().st_mtime == ignored_timestamp
            assert nested.stat().st_mtime == dirty_timestamp
            assert repo.stat().st_mtime == dirty_timestamp

    def test_discover_repos_prunes_git_contents(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            plain_repo = root / "plain"
            (plain_repo / ".git").mkdir(parents=True)
            worktree_project = root / "worktree-project"
            (worktree_project / "trunk").mkdir(parents=True)
            (worktree_project / WORKTREE_GIT_DIR_NAME / "tag-worktree" / ".git").mkdir(
                parents=True
            )

            assert _discover_repos(root) == sorted(
                (plain_repo, worktree_project / TRUNK_DIR_NAME),
                key=lambda path: str(path).casefold(),
            )

    def test_update_processes_repos_while_discovery_is_in_progress(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            first_repo = root / "first"
            second_repo = root / "second"
            first_repo.mkdir()
            second_repo.mkdir()
            events: list[str] = []
            allow_second_discovery = Event()

            def fake_iter(_project: Path):
                events.append("discover:first")
                yield first_repo
                assert allow_second_discovery.wait(1)
                events.append("discover:second")
                yield second_repo

            def fake_process(repo: Path, **_kwargs: object) -> None:
                events.append(f"process:{repo.name}")
                if repo == first_repo:
                    allow_second_discovery.set()

            with (
                patch(f"{__name__}._iter_repos", side_effect=fake_iter),
                patch(f"{__name__}._is_bitbucket_repo", return_value=False),
                patch(f"{__name__}._load_azure_pat", return_value=None),
                patch(f"{__name__}._process_one_repo", side_effect=fake_process),
            ):
                main(
                    root,
                    bitbucket_interval_seconds=0,
                    bitbucket_timeout_seconds=30.0,
                    fix_moved=False,
                    rename_on_move=False,
                    prune_missing=False,
                    sync_branch_worktrees=False,
                    prune_branch_worktrees=False,
                    sync_tag_worktrees=False,
                    prune_tag_worktrees=False,
                    trash_dir=root / ".trash",
                    dry_run=True,
                )

            assert events.index("process:first") < events.index("discover:second")
            assert events[-1] == "process:second"

    def test_tag_worktrees_only_add_missing_tags(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            repo = root / "repo"
            tags_root = root / "tags"
            existing_tag_worktree = tags_root / "v1.0.0"
            new_tag_worktree = tags_root / "v2.0.0"
            repo.mkdir()
            existing_tag_worktree.mkdir(parents=True)
            (existing_tag_worktree / ".git").touch()
            common_dir = root / WORKTREE_GIT_DIR_NAME
            run_git_calls: list[list[str]] = []
            log_events: list[str] = []

            def fake_run_git(
                _repo_path: Path, args: list[str], **_kwargs: object
            ) -> subprocess.CompletedProcess[str]:
                run_git_calls.append(args)
                if args[:3] == ["worktree", "add", "--detach"]:
                    new_tag_worktree.mkdir()
                    (new_tag_worktree / ".git").touch()
                return subprocess.CompletedProcess(args, 0, "", "")

            with (
                patch(
                    f"{__name__}._get_worktree_layout_roots",
                    return_value=(root, tags_root),
                ),
                patch(f"{__name__}._get_git_common_dir", return_value=common_dir),
                patch(f"{__name__}._list_tags", return_value=["v1.0.0", "v2.0.0"]),
                patch(f"{__name__}._run_git", side_effect=fake_run_git),
                patch(
                    f"{__name__}.logger.info",
                    side_effect=lambda event, **_kwargs: log_events.append(event),
                ),
                patch(f"{__name__}.ensure_dprint_config_link", return_value=False),
            ):
                _sync_tag_worktrees(
                    repo,
                    prune_tag_worktrees=False,
                    dry_run=False,
                )

            assert run_git_calls == [
                ["worktree", "add", "--detach", str(new_tag_worktree), "v2.0.0"]
            ]
            assert log_events == ["worktree_tag_add"]

    def test_other_fetch_runs_while_bitbucket_fetch_runs(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            bitbucket_repo = root / "bitbucket"
            other_repo = root / "other"
            bitbucket_repo.mkdir()
            other_repo.mkdir()
            bitbucket_started = Event()
            other_started = Event()
            events: list[str] = []

            def fake_iter(_project: Path):
                yield bitbucket_repo
                yield other_repo

            def fake_process(repo: Path, **kwargs: object) -> None:
                if kwargs["stream"] == "bitbucket":
                    events.append("bitbucket_start")
                    bitbucket_started.set()
                    assert other_started.wait(1)
                    events.append("bitbucket_end")
                else:
                    events.append("other_start")
                    other_started.set()
                    assert bitbucket_started.wait(1)
                    events.append("other_end")

            with (
                patch(f"{__name__}._iter_repos", side_effect=fake_iter),
                patch(
                    f"{__name__}._is_bitbucket_repo",
                    side_effect=[True, False],
                ),
                patch(f"{__name__}._load_azure_pat", return_value=None),
                patch(f"{__name__}._process_one_repo", side_effect=fake_process),
            ):
                main(
                    root,
                    bitbucket_interval_seconds=6,
                    bitbucket_timeout_seconds=30.0,
                    fix_moved=False,
                    rename_on_move=False,
                    prune_missing=False,
                    sync_branch_worktrees=False,
                    prune_branch_worktrees=False,
                    sync_tag_worktrees=False,
                    prune_tag_worktrees=False,
                    trash_dir=root / ".trash",
                    dry_run=True,
                )

            assert events.index("other_start") < events.index("bitbucket_end")

    def test_missing_local_repo_is_skipped(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            totals = {
                "processed": 0,
                "success": 0,
                "failed": 0,
                "skipped": 0,
                "updated": 0,
                "lines": 0,
            }
            with self.assertLogs(level="WARNING") as logs:
                _process_one_repo(
                    root / "missing",
                    stream="other",
                    totals=totals,
                    total_repos=1,
                    bitbucket_interval_seconds=0,
                    bitbucket_timeout_seconds=6.0,
                    azure_pat=None,
                    fix_moved=False,
                    rename_on_move=False,
                    prune_missing=False,
                    sync_branch_worktrees=False,
                    prune_branch_worktrees=False,
                    sync_tag_worktrees=False,
                    prune_tag_worktrees=False,
                    project=root,
                    trash_dir=root / ".trash",
                    dry_run=True,
                )
            assert "repo_skipped" in logs.output[0]
            assert totals["skipped"] == 1
            assert totals["processed"] == 0

    def test_azure_pat_falls_back_to_git_credential_helper(self) -> None:
        with TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            origin = "https://example-org@dev.azure.com/example-org/example-project/_git/example"
            fetch_envs: list[dict[str, str] | None] = []

            def fake_run_git(
                _repo_path: Path, args: list[str], **kwargs: object
            ) -> subprocess.CompletedProcess[str]:
                if args == ["remote", "get-url", "origin"]:
                    return subprocess.CompletedProcess(args, 0, origin, "")
                fetch_envs.append(kwargs.get("env"))
                if len(fetch_envs) == 1:
                    return subprocess.CompletedProcess(
                        args,
                        128,
                        "fatal: could not read Password: terminal prompts disabled",
                        "",
                    )
                return subprocess.CompletedProcess(args, 0, "From example\n", "")

            with patch(f"{__name__}._run_git", side_effect=fake_run_git):
                result = fetch_repo(
                    repo,
                    **self._fetch_options(azure_pat="invalid-pat", dry_run=False),  # type: ignore[arg-type]
                )

            assert result[0]
            assert result[1]
            assert len(fetch_envs) == 3
            assert fetch_envs[0]["GIT_CONFIG_COUNT"] == "2"
            assert fetch_envs[1]["GIT_TERMINAL_PROMPT"] == "0"
            assert fetch_envs[2]["GIT_TERMINAL_PROMPT"] == "0"

    def test_azure_fetch_uses_timeout(self) -> None:
        with TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            origin = "git@ssh.dev.azure.com:v3/example-org/example-project/example"
            fetch_kwargs: list[dict[str, object]] = []

            def fake_run_git(
                _repo_path: Path, args: list[str], **kwargs: object
            ) -> subprocess.CompletedProcess[str]:
                if args == ["remote", "get-url", "origin"]:
                    return subprocess.CompletedProcess(args, 0, origin, "")
                fetch_kwargs.append(kwargs)
                return subprocess.CompletedProcess(args, 0, "", "")

            with patch(f"{__name__}._run_git", side_effect=fake_run_git):
                result = fetch_repo(
                    repo,
                    **self._fetch_options(dry_run=False),  # type: ignore[arg-type]
                )

            assert result[0]
            assert len(fetch_kwargs) == 2
            assert all(
                isinstance(kwargs["timeout"], float) and kwargs["timeout"] > 0.0
                for kwargs in fetch_kwargs
            )

    def test_bitbucket_fetch_uses_timeout(self) -> None:
        with TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            origin = "ssh://git@bitbucket.org/project/example.git"
            fetch_kwargs: list[dict[str, object]] = []

            def fake_run_git(
                _repo_path: Path, args: list[str], **kwargs: object
            ) -> subprocess.CompletedProcess[str]:
                if args == ["remote", "get-url", "origin"]:
                    return subprocess.CompletedProcess(args, 0, origin, "")
                fetch_kwargs.append(kwargs)
                return subprocess.CompletedProcess(args, 0, "", "")

            with patch(f"{__name__}._run_git", side_effect=fake_run_git):
                result = fetch_repo(
                    repo,
                    **self._fetch_options(dry_run=False),  # type: ignore[arg-type]
                )

            assert result[0]
            assert len(fetch_kwargs) == 2
            for kwargs in fetch_kwargs:
                timeout = kwargs["timeout"]
                assert isinstance(timeout, float)
                assert timeout > 0.0
                assert timeout <= DEFAULT_BITBUCKET_TIMEOUT_SECONDS

    def test_bitbucket_retries_use_the_call_interval(self) -> None:
        with TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            origin = "ssh://git@bitbucket.org/project/example.git"
            fetch_calls = 0
            wait_calls: list[tuple[int, str]] = []

            def fake_run_git(
                _repo_path: Path, args: list[str], **_kwargs: object
            ) -> subprocess.CompletedProcess[str]:
                nonlocal fetch_calls
                if args == ["remote", "get-url", "origin"]:
                    return subprocess.CompletedProcess(args, 0, origin, "")
                fetch_calls += 1
                if fetch_calls == 1:
                    return subprocess.CompletedProcess(
                        args, 128, "connection reset by peer", ""
                    )
                return subprocess.CompletedProcess(args, 0, "", "")

            def fake_wait(interval_seconds: int, *, reason: str) -> None:
                wait_calls.append((interval_seconds, reason))

            with (
                patch(f"{__name__}._run_git", side_effect=fake_run_git),
                patch(f"{__name__}._wait_for_bitbucket_slot", side_effect=fake_wait),
            ):
                result = fetch_repo(
                    repo,
                    **self._fetch_options(
                        bitbucket_interval_seconds=6,
                        bitbucket_timeout_seconds=30.0,
                    ),  # type: ignore[arg-type]
                )

            assert result[0]
            assert wait_calls == [(6, "bitbucket_call"), (6, "bitbucket_retry")]

    def test_bitbucket_quiet_fetch_uses_the_throttle_delay(self) -> None:
        with TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            origin = "ssh://git@bitbucket.org/project/example.git"
            fetch_calls: list[list[str]] = []
            wait_calls: list[tuple[int, str]] = []

            def fake_run_git(
                _repo_path: Path, args: list[str], **_kwargs: object
            ) -> subprocess.CompletedProcess[str]:
                if args == ["remote", "get-url", "origin"]:
                    return subprocess.CompletedProcess(args, 0, origin, "")
                fetch_calls.append(args)
                return subprocess.CompletedProcess(args, 0, "", "")

            def fake_wait(interval_seconds: int, *, reason: str) -> None:
                wait_calls.append((interval_seconds, reason))

            with (
                patch(f"{__name__}._run_git", side_effect=fake_run_git),
                patch(f"{__name__}._wait_for_bitbucket_slot", side_effect=fake_wait),
            ):
                result = fetch_repo(
                    repo,
                    **self._fetch_options(
                        bitbucket_interval_seconds=6,
                        bitbucket_timeout_seconds=30.0,
                        dry_run=False,
                    ),  # type: ignore[arg-type]
                )

            assert result[0]
            assert len(fetch_calls) == 2
            assert wait_calls == [(6, "bitbucket_call"), (6, "bitbucket_fetch")]

    def test_missing_remote_is_skipped(self) -> None:
        with TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            origin = "https://dev.azure.com/example-org/example-project/_git/example"

            def fake_run_git(
                _repo_path: Path, args: list[str], **_kwargs: object
            ) -> subprocess.CompletedProcess[str]:
                if args == ["remote", "get-url", "origin"]:
                    return subprocess.CompletedProcess(args, 0, origin, "")
                return subprocess.CompletedProcess(
                    args,
                    128,
                    "remote: TF401019: The Git repository with name or identifier example does not exist or you do not have permissions for the operation you are attempting.\n\ncommand timed out after 30.0s",
                    "",
                )

            with (
                self.assertLogs(level="WARNING") as logs,
                patch(f"{__name__}._run_git", side_effect=fake_run_git),
            ):
                result = fetch_repo(repo, **self._fetch_options())  # type: ignore[arg-type]

            assert "repo_skipped" in logs.output[0]
            assert not result[0]
            assert result[4]


@cli.command("test", short_help="Run local, network-free regression tests.")
@click.option("--verbose", "-v", count=True, help="Show each test case")
def test_command(verbose: int) -> None:
    """Run the script's local regression tests without contacting remotes."""
    configure_logging(0)
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2 if verbose else 1)
    with patch(f"{__name__}.BITBUCKET_HOST", "bitbucket.org"):
        result = runner.run(suite)
    if not result.wasSuccessful():
        raise click.exceptions.Exit(1)


if __name__ == "__main__":
    cli()
