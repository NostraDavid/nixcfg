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
            **os.environ,
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
        for branch in ("main", "master"):
            self.git("symbolic-ref", "HEAD", f"refs/heads/{branch}")
            result = self.run_command(hook)
            self.assertEqual(result.returncode, 1)
            self.assertIn("Create a feature branch", result.stdout)
        for origin in (
            "https://bitbucket.alfa.local/team/repo.git",
            "git@tennet.ghe.com:team/repo.git",
            "https://dev.azure.com/team/repo",
            "https://team.visualstudio.com/repo",
        ):
            self.git("config", "remote.origin.url", origin)
            self.git("symbolic-ref", "HEAD", "refs/heads/feature")
            self.assertEqual(self.run_command(hook).returncode, 1)
            for branch in (
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

    def test_aliases_set_upstream_bootstrap_and_preserve_failures(self) -> None:
        self.git("update-ref", "refs/remotes/origin/feature", "HEAD")
        self.git("config", "remote.origin.url", str(self.repo))
        self.git("config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*")
        self.executable(self.bin / "fzf", "cat >/dev/null; echo feature")
        bootstrap = self.home / "dev/bootstrap_repo_local_configs.sh"
        self.executable(bootstrap, 'printf "%s\\n" "$PWD|$*" >> "$HOME/bootstrap.log"')
        self.git("co", "feature")
        self.assertEqual(
            self.git("rev-parse", "--abbrev-ref", "feature@{upstream}"),
            "origin/feature",
        )
        self.git("branch", "other")
        worktree = self.home / "other"
        self.git("wta", "other", str(worktree))
        log = (self.home / "bootstrap.log").read_text()
        self.assertIn(f"{self.repo}|\n", log)
        self.assertIn(f"{self.repo}|{worktree}\n", log)
        result = self.run_command("git", "wta", "missing", str(self.home / "missing"))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.home / "bootstrap.log").read_text(), log)
        self.git("wtinit", str(self.repo), str(self.home / "clone"), "feature")
        self.assertIn(
            f"{self.home / 'clone'}|trunk\n", (self.home / "bootstrap.log").read_text()
        )
        bootstrap.unlink()
        self.git("co", "feature")
        self.git("branch", "without-bootstrap")
        self.git("wta", "without-bootstrap", str(self.home / "without-bootstrap"))


if __name__ == "__main__":
    unittest.main()
