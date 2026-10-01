#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["structlog>=26.1.0"]
# ///
"""Check shared commands against temporary repositories, without network access."""

import importlib.util
import os
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import Mock, patch

BIN = Path(__file__).resolve().parents[1] / ".local/bin"


def load(name):
    spec = importlib.util.spec_from_file_location(
        name.replace("-", "_"), BIN / f"{name}.py"
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


ide = load("ide")
picker = load("project_picker")
scanner = load("find-uncommitted")
saver = load("save_cloned_repos")
timestamps = load("repo_timestamps")


class MigrationTests(unittest.TestCase):
    def test_vscode_wrapper_and_electron_environment(self):
        with TemporaryDirectory() as directory:
            candidate = Path(directory) / "code"
            candidate.write_text("#!/bin/sh\nprintf '1.0\\n'\n")
            candidate.chmod(0o755)
            with patch.dict(
                os.environ,
                {
                    "PATH": directory,
                    "VSCODE_IPC_HOOK_CLI": "socket",
                    "ELECTRON_RUN_AS_NODE": "1",
                },
            ):
                self.assertEqual(ide.find_code_command(), [str(candidate)])
                env = ide.clean_vscode_env(preserve_vscode_ipc_hook_cli=True)
                self.assertNotIn("ELECTRON_RUN_AS_NODE", env)
                self.assertEqual(env["VSCODE_IPC_HOOK_CLI"], "socket")
                self.assertEqual(
                    ide.clean_vscode_env(electron_cli=True)["ELECTRON_RUN_AS_NODE"], "1"
                )

    def test_picker_roots_and_targeted_query(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            dev, users = root / "dev", root / "users"
            dev_repo = dev / "org/repo"
            current = users / "user/new"
            (dev_repo / "worktree.git").mkdir(parents=True)
            (current / "worktree.git").mkdir(parents=True)
            trunk = current / "trunk"
            trunk.mkdir()
            repos = picker.discover_all_repos((dev, users))
            self.assertEqual(
                repos, [("org/repo", dev_repo), ("users/user/new", current)]
            )
            choice = picker.WorktreeChoice("trunk", trunk, "branch", "master", False)
            with patch.object(
                picker, "list_worktrees", return_value=[choice]
            ) as listing:
                self.assertEqual(
                    picker.resolve_worktree_query(repos, "users new", root), trunk
                )
                listing.assert_called_once_with(current)
            self.assertEqual(
                picker.discover_all_repos((root / "absent", users)),
                [("users/user/new", current)],
            )

    def test_worktree_scan_inventory_and_timestamp_preservation(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            repo = root / "repo"

            def git(*args):
                return subprocess.run(
                    [
                        "git",
                        "-c",
                        "core.hooksPath=/dev/null",
                        "-c",
                        "user.name=Test",
                        "-c",
                        "user.email=test@example.test",
                        *args,
                    ],
                    cwd=root,
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout.strip()

            git("init", str(repo))
            tracked = repo / "tracked.txt"
            tracked.write_text("committed\n")
            git("-C", str(repo), "add", ".")
            git("-C", str(repo), "commit", "-m", "Initial")
            worktree = root / "worktree"
            git("-C", str(repo), "worktree", "add", "-b", "feature", str(worktree))
            (worktree / "untracked.txt").write_text("local\n")
            self.assertIn(worktree / ".git", scanner.git_dirs(root))
            with (
                patch.object(scanner, "parse_args", return_value=Mock(search_dir=root)),
                patch.object(scanner, "logger") as logger,
            ):
                self.assertEqual(scanner.main(), 0)
                self.assertIn(
                    unittest.mock.call(
                        "repo_has_uncommitted_changes", repo=str(worktree)
                    ),
                    logger.warning.call_args_list,
                )
            git(
                "-C",
                str(repo),
                "remote",
                "add",
                "origin",
                "https://user:secret@example.test/team/repo.git",
            )
            inventory = root / "state/repos.dat"
            args = Mock(search_dir=root, repos_file=inventory, dry_run=False)
            with patch.object(saver, "parse_args", return_value=args):
                self.assertEqual(saver.main(), 0)
            self.assertEqual(
                inventory.read_text(), "https://example.test/team/repo.git\n"
            )
            self.assertEqual(
                saver.without_credentials("git@example.test:team/repo.git"),
                "git@example.test:team/repo.git",
            )
            before = inventory.read_bytes()
            args.dry_run = True
            with (
                patch.object(saver, "parse_args", return_value=args),
                patch("builtins.print"),
            ):
                self.assertEqual(saver.main(), 0)
            self.assertEqual(inventory.read_bytes(), before)
            committed_time = int(git("-C", str(repo), "log", "-1", "--format=%ct"))
            tracked.write_text("dirty\n")
            os.utime(tracked, (committed_time + 100, committed_time + 100))
            clean = worktree / "tracked.txt"
            os.utime(clean, (committed_time + 200, committed_time + 200))
            timestamps.refresh_repository_tree(repo)
            self.assertEqual(tracked.stat().st_mtime, committed_time + 100)
            timestamps.refresh_repository_tree(worktree)
            self.assertEqual(clean.stat().st_mtime, committed_time)


if __name__ == "__main__":
    unittest.main()
