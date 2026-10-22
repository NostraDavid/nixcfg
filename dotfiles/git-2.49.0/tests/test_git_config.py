from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[1] / ".config/git"


class GitConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.repo = self.home / "dev/repo"
        self.repo.mkdir(parents=True)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env = {
            **{
                key: value
                for key, value in os.environ.items()
                if not key.startswith("GIT_")
            },
            "HOME": str(self.home),
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "GIT_CONFIG_GLOBAL": str(CONFIG / "common.conf"),
            "GIT_CONFIG_NOSYSTEM": "1",
        }
        self.git("init", "-q", "-b", "feature")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.org")
        self.git("config", "commit.gpgsign", "false")
        self.git("commit", "-q", "--allow-empty", "-m", "test: initial")

    def run_command(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(  # noqa: S603 - fixed commands in disposable repositories
            args,
            cwd=self.repo,
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
        )

    def git(self, *args: str) -> str:
        result = self.run_command(
            "git", "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false", *args
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def executable(self, path: Path, body: str) -> None:
        path.write_text("#!/bin/sh\n" + body + "\n")
        path.chmod(0o755)

    def test_pre_commit_branch_rules_and_config_formats(self) -> None:
        hook = str(CONFIG / "hooks/pre-commit")
        self.executable(self.bin / "prek", 'printf "%s\\n" "$*"; exit 7')
        for origin in (None, "git@github.com:NostraDavid/nixcfg.git"):
            if origin is not None:
                self.git("config", "remote.origin.url", origin)
            for branch in ("main", "master"):
                self.git("symbolic-ref", "HEAD", f"refs/heads/{branch}")
                self.assertEqual(self.run_command(hook).returncode, 0)
        for origin in (
            "https://bitbucket.example.com/team/repo.git",
            "git@company.ghe.com:team/repo.git",
            "https://dev.azure.com/team/repo",
            "https://team.visualstudio.com/repo",
        ):
            self.git("config", "remote.origin.url", origin)
            for branch in ("main", "master"):
                self.git("symbolic-ref", "HEAD", f"refs/heads/{branch}")
                result = self.run_command(hook)
                self.assertEqual(result.returncode, 1)
                self.assertIn("Create a feature branch", result.stdout)
            for branch in (
                "feature",
                "SOCM-12-description",
                "SOCM-12345-description",
                "SOCM-1234-",
                "SOCM-1234-description.with.period",
            ):
                self.git("symbolic-ref", "HEAD", f"refs/heads/{branch}")
                self.assertEqual(self.run_command(hook).returncode, 1)
            for branch in (
                "SOCM-1234-somerandomestring-with-dashes-only",
                "SOCM-123-description",
                "SOCM-1234-description_with_underscores",
                "socm-123-description",
            ):
                self.git("symbolic-ref", "HEAD", f"refs/heads/{branch}")
                self.assertEqual(self.run_command(hook).returncode, 0)
        for config in (
            "prek.toml",
            ".pre-commit-config.yaml",
            ".pre-commit-config.yml",
        ):
            path = self.repo / config
            path.touch()
            result = self.run_command(hook)
            self.assertEqual(result.returncode, 7)
            self.assertEqual(result.stdout, "run --stage pre-commit\n")
            path.unlink()
        self.git("config", "remote.origin.url", "https://github.com/team/repo.git")
        self.git("symbolic-ref", "HEAD", "refs/heads/feature")
        self.assertEqual(self.run_command(hook).returncode, 0)
        self.repo = self.home / "outside"
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        (self.repo / "prek.toml").touch()
        self.assertEqual(self.run_command(hook).returncode, 0)

    def test_pre_push_skips_azure_and_preserves_lfs_status(self) -> None:
        self.executable(self.bin / "git-lfs", 'printf "%s\\n" "$*"; exit 7')
        hook = str(CONFIG / "hooks/pre-push")
        for url in (
            "https://dev.azure.com/team/repo",
            "git@ssh.dev.azure.com:v3/team/project/repo",
            "https://team.visualstudio.com/repo",
            "git@team.visualstudio.com:repo",
        ):
            result = self.run_command(hook, "origin", url)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
        result = self.run_command(hook, "origin", "https://github.com/team/repo.git")
        self.assertEqual(result.returncode, 7)
        self.assertIn("pre-push origin https://github.com/team/repo.git", result.stdout)

    def test_diff_tools_use_local_bin_with_spaces_in_home(self) -> None:
        self.env["HOME"] = str(self.home / "user home")
        local_bin = Path(self.env["HOME"]) / ".local/bin"
        local_bin.mkdir(parents=True)
        for name in ("difft", "delta", "mergiraf"):
            self.executable(local_bin / name, f"printf 'local {name}\\n'")
            self.executable(self.bin / name, "exit 99")
        document = self.repo / "example.txt"
        document.write_text("before\n")
        self.git("add", "example.txt")
        self.git("commit", "-qm", "test: add example")
        document.write_text("after\n")
        for args in (("diff",), ("ddiff",), ("difftool",)):
            self.assertEqual(self.git(*args), "local difft")
        self.git("config", "diff.external", "false")
        for args in (
            ("ddiff",),
            ("dlog", "--format=", "-p", "-1"),
            ("dshow", "--format="),
        ):
            self.assertEqual(self.git(*args), "local difft")
        for key, expected in (
            ("pager.diff", "local delta"),
            ("pager.show", "local delta"),
            ("pager.log", "local delta"),
            ("merge.mergiraf.driver", "local mergiraf"),
        ):
            result = self.run_command("sh", "-c", self.git("config", "--get", key))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), expected)

    def test_aliases_set_upstream_and_preserve_failures(self) -> None:
        self.git("update-ref", "refs/remotes/origin/feature", "HEAD")
        self.git("config", "remote.origin.url", str(self.repo))
        self.git("config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*")
        self.executable(self.bin / "fzf", "cat >/dev/null; echo feature")
        self.git("co", "feature")
        self.assertEqual(
            self.git("rev-parse", "--abbrev-ref", "feature@{upstream}"),
            "origin/feature",
        )
        self.git("branch", "other")
        worktree = self.home / "other"
        self.git("wta", "other", str(worktree))
        self.assertEqual(
            self.git("-C", str(worktree), "branch", "--show-current"), "other"
        )
        result = self.run_command("git", "wta", "missing", str(self.home / "missing"))
        self.assertNotEqual(result.returncode, 0)
        self.git("wtinit", str(self.repo), str(self.home / "clone"), "feature")
        trunk = self.home / "clone/trunk"
        self.assertEqual(
            self.git("-C", str(trunk), "branch", "--show-current"), "feature"
        )
        self.assertEqual(
            self.git("-C", str(trunk), "rev-parse", "--abbrev-ref", "@{upstream}"),
            "origin/feature",
        )


if __name__ == "__main__":
    unittest.main()
