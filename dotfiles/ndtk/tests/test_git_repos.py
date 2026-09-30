#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["dotenv", "niquests", "structlog"]
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
SCRIPTS = (
    "find-uncommitted",
    "get_azure_repos",
    "grab",
    "restore_repos",
    "save_cloned_repos",
    "update_all_local_repos",
)


def check() -> None:
    with tempfile.TemporaryDirectory(prefix="ndtk-test-") as directory:
        root = Path(directory)
        env = dict(os.environ)
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
            (commands / name).symlink_to(BIN / f"{name}.py")

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
        assert str(config / "repos.dat") in run("restore_repos", "--help").stdout
        state_file = root / "state/ndtk/repos.dat"
        assert str(state_file) in run("save_cloned_repos", "--help").stdout

        target = root / "checkout"
        result = run("restore_repos", str(target))
        assert result.returncode == 1, result.stderr
        assert str(config / "repos.dat") in result.stdout + result.stderr
        assert not target.exists()

        (root / ".env").write_text("AZDO_PAT=ignored\nAZDO_ORG_URL=ignored\n")
        result = run("get_azure_repos")
        assert result.returncode == 1, result.stderr
        assert str(config / "azure.env") in result.stderr
        assert "AZDO_PAT" in result.stderr and "AZDO_ORG_URL" in result.stderr
        assert "Configuration file missing" in result.stderr

        (config / "azure.env").write_text("AZDO_ORG_URL=https://example.test/org/\n")
        result = run("get_azure_repos")
        assert result.returncode == 1, result.stderr
        assert "Missing settings: AZDO_PAT." in result.stderr
        assert "Configuration file missing" not in result.stderr

        (config / "azure.env").write_text(
            "AZDO_ORG_URL=https://example.test/org/\nAZDO_PAT=file-token\n"
        )
        with patch.dict(os.environ, env, clear=True):
            azure = runpy.run_path(str(BIN / "get_azure_repos.py"))
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
        assert run("restore_repos", str(target)).returncode == 0
        scan = root / "scan"
        scan.mkdir()
        result = run("save_cloned_repos", str(scan))
        assert result.returncode == 0, result.stderr
        assert state_file.read_text() == ""
        assert repos_file.read_text() == "# Empty list\n"
        explicit = root / "inventory.dat"
        assert run("save_cloned_repos", str(scan), str(explicit)).returncode == 0
        assert explicit.is_file()
        assert (
            run("restore_repos", "--repos-file", str(explicit), str(target)).returncode
            == 0
        )

        env["XDG_CONFIG_HOME"] = ""
        env["XDG_STATE_HOME"] = ""
        assert (
            str(Path.home() / ".config/ndtk/repos.dat")
            in run("restore_repos", "--help").stdout
        )
        assert (
            str(Path.home() / ".local/state/ndtk/repos.dat")
            in run("save_cloned_repos", "--help").stdout
        )
    print("ok")


if __name__ == "__main__":
    check()
