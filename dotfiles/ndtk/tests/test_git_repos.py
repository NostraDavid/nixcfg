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


def check() -> None:
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
        assert "--dry-run" in run("repos", "local", "update", "--help").stdout
        empty = root / "empty"
        empty.mkdir()
        result = run("repos", "local", "check", "--project", str(empty))
        assert result.returncode == 0, result.stderr
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
