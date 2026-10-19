#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["dotenv", "niquests", "structlog", "click", "pytest", "pytest-cov", "stamina"]
# ///

"""Run directly to check repository commands without accessing remote services."""

import base64
import os
import runpy
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

BIN = Path(__file__).resolve().parents[1] / ".local/bin"
PROVIDERS = tuple(
    path.stem.removeprefix("_repos_") for path in sorted(BIN.glob("_repos_*.py"))
)
SCRIPTS = (
    "find-uncommitted",
    "repos",
    "restore_repos",
    "save_cloned_repos",
)


def check_provider_checkout_updates() -> None:
    sys.path.insert(0, str(BIN))
    for provider in ("azure", "github"):
        module = runpy.run_path(str(BIN / f"_repos_{provider}.py"))
        sync = module["clone_or_update_repo"]
        sync.__globals__["ensure_dprint_config_link"] = lambda _path: False
        for scenario in ("dirty", "conflict", "diverged"):
            with tempfile.TemporaryDirectory(prefix=f"repos-{provider}-") as directory:
                root = Path(directory)
                source = root / "source"
                project = root / "project"
                repo = project / "source"
                env = {
                    key: value
                    for key, value in os.environ.items()
                    if not key.startswith("GIT_")
                }

                def git(path: Path, *args: str) -> str:
                    return subprocess.check_output(
                        [
                            "git",
                            "-C",
                            str(path),
                            "-c",
                            "core.hooksPath=/dev/null",
                            "-c",
                            "commit.gpgsign=false",
                            "-c",
                            "user.name=Local check",
                            "-c",
                            "user.email=check@example.invalid",
                            *args,
                        ],
                        env=env,
                        stderr=subprocess.STDOUT,
                        text=True,
                    ).strip()

                def commit(path: Path, message: str) -> None:
                    git(path, "add", ".")
                    git(path, "commit", "-qm", message)

                def update() -> tuple:
                    return sync(
                        str(source),
                        repo if provider == "azure" else project,
                        ["master", "z-other"],
                        [],
                        False,
                        True,
                        False,
                        fetch_timeout=300,
                    )

                with patch.dict(os.environ, env, clear=True):
                    git(root, "init", "-qb", "master", str(source))
                    (source / "file.txt").write_text("initial\n")
                    commit(source, "initial")
                    git(source, "branch", "z-other")
                    result = update()
                    assert result[-2], result
                    trunk = repo / "trunk"
                    # Existing stashes and the second branch must survive any failure.
                    (trunk / "file.txt").write_text("old stash\n")
                    git(trunk, "stash", "push", "-qm", "existing stash")
                    old_stash = git(trunk, "rev-parse", "refs/stash")
                    if scenario == "diverged":
                        (trunk / "local.txt").write_text("local commit\n")
                        commit(trunk, "local commit")
                    head = git(trunk, "rev-parse", "HEAD")
                    if scenario == "dirty":
                        (trunk / "file.txt").write_text("staged\n")
                        git(trunk, "add", "file.txt")
                    (trunk / "file.txt").write_text("local changes\n")
                    (trunk / "untracked.txt").write_text("untracked\n")
                    (
                        source
                        / ("file.txt" if scenario == "conflict" else "remote.txt")
                    ).write_text("remote\n")
                    commit(source, "remote commit")
                    target = git(source, "rev-parse", "HEAD")
                    git(source, "branch", "-f", "z-other", target)
                    result = update()
                    assert result[-2] == (scenario == "dirty"), (
                        provider,
                        scenario,
                        result,
                    )
                    assert git(repo / "z-other", "rev-parse", "HEAD") == target
                    if scenario == "conflict":
                        assert (
                            git(trunk, "show", "refs/stash:file.txt") == "local changes"
                        )
                        assert "file.txt" in git(
                            trunk, "diff", "--name-only", "--diff-filter=U"
                        )
                        assert old_stash in git(trunk, "stash", "list", "--format=%H")
                    else:
                        assert (trunk / "file.txt").read_text() == "local changes\n"
                        assert (trunk / "untracked.txt").read_text() == "untracked\n"
                        assert git(trunk, "rev-parse", "refs/stash") == old_stash
                        assert git(trunk, "rev-parse", "HEAD") == (
                            head if scenario == "diverged" else target
                        )
                        if scenario == "dirty":
                            assert git(trunk, "show", ":file.txt") == "staged"
    print(
        "azure/github: dirty updates, staged/untracked preservation, conflicts and divergence passed"
    )


def check() -> None:
    check_provider_checkout_updates()
    with tempfile.TemporaryDirectory(prefix="ndtk-test-") as directory:
        root = Path(directory)
        # Commit hooks export Git paths that must not reach temporary repositories.
        env = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith("GIT_")
        }
        env["UV_CACHE_DIR"] = subprocess.check_output(
            ["uv", "cache", "dir"], text=True
        ).strip()
        for key in ("AZDO_PAT", "AZDO_ORG_URL", "PYTHON_DOTENV_DISABLED"):
            env.pop(key, None)
        env["XDG_CONFIG_HOME"] = str(root / "config")
        env["XDG_STATE_HOME"] = str(root / "state")
        env["COLUMNS"] = "240"
        config = root / "config/ndtk"
        config.mkdir(parents=True)
        commands = root / "bin"
        commands.mkdir()
        for name in SCRIPTS:
            suffix = ".sh" if name == "repos" else ".py"
            (commands / name).symlink_to(BIN / f"{name}{suffix}")
        env["HOME"] = str(root / "home")
        helpers = root / "home/.local/bin"
        helpers.mkdir(parents=True)
        for provider in PROVIDERS:
            (helpers / f"_repos_{provider}.py").symlink_to(
                BIN / f"_repos_{provider}.py"
            )
        (helpers / "_repo_checkouts.py").symlink_to(BIN / "_repo_checkouts.py")

        def run(name: str, *args: str) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                [str(commands / name), *args],
                cwd=root,
                env=env,
                capture_output=True,
                text=True,
                check=False,
                timeout=60,
            )

        for name in SCRIPTS:
            result = run(name, "--help")
            assert result.returncode == 0, (name, result.stderr)
        for arguments in ((), ("help",)):
            result = run("repos", *arguments)
            assert result.returncode == 0, result.stderr
            assert result.stdout == run("repos", "--help").stdout
        for provider in PROVIDERS:
            result = run("repos", provider, "--help")
            assert result.returncode == 0, (provider, result.stderr)
            assert f"repos {provider}" in result.stdout
            for command in ("help", "check", "test"):
                assert command in result.stdout, (provider, command, result.stdout)
                command_help = run("repos", provider, command, "--help")
                assert command_help.returncode == 0, (
                    provider,
                    command,
                    command_help.stderr,
                )
                topic_help = run("repos", provider, "help", command)
                assert topic_help.returncode == 0, topic_help.stderr
                assert topic_help.stdout.strip() == command_help.stdout.strip()
            for arguments in ((), ("help",)):
                help_result = run("repos", provider, *arguments)
                assert help_result.returncode == 0, (
                    provider,
                    arguments,
                    help_result.stderr,
                )
                assert help_result.stdout.strip() == result.stdout.strip(), (
                    provider,
                    arguments,
                )
            invalid = run("repos", provider, "unknown-command")
            assert invalid.returncode == 2, (provider, invalid.stderr)
            tests = run("repos", provider, "test")
            assert tests.returncode == 0, (provider, tests.stderr)
        result = run("repos", "unknown-provider")
        assert result.returncode == 2 and "Unknown provider" in result.stderr
        for option in ("--clone-timeout", "--fetch-timeout", "--workers"):
            for value in ("0", "-1"):
                result = run("repos", "azure", "clone", option, value)
                assert result.returncode == 2, (option, value, result.stderr)
                assert "greater than zero" in result.stderr
        result = run("repos", "azure", "clone", "--workers", "invalid")
        assert result.returncode == 2 and "invalid int value" in result.stderr
        assert "--workers" in run("repos", "azure", "clone", "--help").stdout
        assert "--dry-run" in run("repos", "local", "update", "--help").stdout
        assert "dirty" in run("repos", "local", "--help").stdout
        assert "--project" in run("repos", "local", "dirty", "--help").stdout
        empty = root / "empty"
        empty.mkdir()
        result = run("repos", "local", "check", "--project", str(empty))
        assert result.returncode == 0, result.stderr
        dirty = run("repos", "local", "dirty", "--project", str(empty))
        assert dirty.returncode == 0 and dirty.stdout == "", dirty.stderr
        result = run("repos", "local", "update", "--project", str(empty), "--dry-run")
        assert result.returncode == 0, result.stderr
        assert list(empty.iterdir()) == []
        assert "--repos-file" in run("restore_repos", "restore", "--help").stdout
        state_file = root / "state/ndtk/repos.dat"
        assert (
            "SEARCH_DIR/repos.dat" in run("save_cloned_repos", "save", "--help").stdout
        )

        target = root / "checkout"
        result = run("restore_repos", "restore", str(target))
        assert result.returncode == 1, result.stderr
        assert str(config / "repos.dat") in result.stdout + result.stderr
        assert not target.exists()

        (root / ".env").write_text("AZDO_PAT=ignored\nAZDO_ORG_URL=ignored\n")
        result = run("repos", "azure", "check")
        assert result.returncode == 1, result.stderr
        assert str(config / "azure.env") in result.stderr
        assert "AZDO_PAT" in result.stderr and "AZDO_ORG_URL" in result.stderr
        assert "Configuration file missing" in result.stderr

        (config / "azure.env").write_text("AZDO_ORG_URL=https://example.test/org/\n")
        result = run("repos", "azure", "check")
        assert result.returncode == 1, result.stderr
        assert "Missing settings: AZDO_PAT." in result.stderr
        assert "Configuration file missing" not in result.stderr

        (config / "azure.env").write_text(
            "AZDO_ORG_URL=https://example.test/org/\nAZDO_PAT=file-token\n"
        )
        with patch.dict(os.environ, env, clear=True):
            azure = runpy.run_path(str(BIN / "_repos_azure.py"))
            configure = azure["configure_auth"]
            configure()
            assert configure.__globals__["API_BASE"] == "https://example.test/org/_apis"
            assert (
                configure.__globals__["basic_auth"]
                == base64.b64encode(b":file-token").decode()
            )
            os.environ["AZDO_PAT"] = "environment-token"
            configure()
            assert (
                configure.__globals__["basic_auth"]
                == base64.b64encode(b":environment-token").decode()
            )
        assert "file-token" not in result.stdout + result.stderr

        repos_file = config / "repos.dat"
        repos_file.write_text("# Empty list\n")
        assert run("restore_repos", "restore", str(target)).returncode == 0
        scan = root / "scan"
        scan.mkdir()
        result = run("save_cloned_repos", "save", str(scan))
        assert result.returncode == 0, result.stderr
        assert (scan / "repos.dat").read_text() == ""
        assert not state_file.exists()
        assert repos_file.read_text() == "# Empty list\n"
        explicit = root / "inventory.dat"
        assert (
            run(
                "save_cloned_repos", "save", str(scan), "--output", str(explicit)
            ).returncode
            == 0
        )
        assert explicit.is_file()
        assert (
            run(
                "restore_repos", "restore", "--repos-file", str(explicit), str(target)
            ).returncode
            == 0
        )

        helper = helpers / "_repos_github.py"
        helper.unlink()
        helper.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\nexit 7\n')
        helper.chmod(0o755)
        arguments = ("clone", "target with spaces", "--tags", "v1,v2")
        result = run("repos", "github", *arguments)
        assert result.returncode == 7
        assert result.stdout.splitlines() == list(arguments)
        assert result.stderr == ""

        env["XDG_CONFIG_HOME"] = ""
        env["XDG_STATE_HOME"] = ""
        env["HOME"] = str(root / "home")
        result = run("restore_repos", "check")
        assert result.returncode == 1, result.stderr
        assert str(root / "home/.config/ndtk/repos.dat") in result.stderr, result.stderr
        assert (
            "SEARCH_DIR/repos.dat" in run("save_cloned_repos", "save", "--help").stdout
        )
    print("ok")


if __name__ == "__main__":
    check()
