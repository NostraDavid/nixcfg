from __future__ import annotations

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from types import ModuleType
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).resolve().parents[1] / ".local/bin/project_picker.py"


def load_project_picker() -> ModuleType:
    spec = importlib.util.spec_from_file_location("project_picker_under_test", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


project_picker = load_project_picker()


class WorktreeListingTests(unittest.TestCase):
    def test_tag_worktrees_hide_duplicate_detached_choices(self) -> None:
        with TemporaryDirectory() as directory:
            repo_root = Path(directory)
            bare_dir = repo_root / "worktree.git"

            def git(*args: str, input_text: str | None = None) -> str:
                return subprocess.run(
                    [
                        "git",
                        "-c",
                        "user.name=Test",
                        "-c",
                        "user.email=test@example.com",
                        "--git-dir",
                        str(bare_dir),
                        *args,
                    ],
                    input=input_text,
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout.strip()

            git("init", "--bare")
            tree = git("hash-object", "-t", "tree", "--stdin", input_text="")
            commit = git("commit-tree", tree, "-m", "Initial commit")
            git("update-ref", "refs/heads/master", commit)
            git("worktree", "add", str(repo_root / "trunk"), "master")
            for tag in ("v1.0", "v1.1", "feature-PR-123"):
                git("tag", "-a", tag, commit, "-m", tag)
                git("worktree", "add", "--detach", str(repo_root / tag), tag)
            git("worktree", "add", "--detach", str(repo_root / "scratch"), commit)

            choices = project_picker.list_worktrees(repo_root)

        self.assertCountEqual(
            [(choice.path.name, choice.kind, choice.ref) for choice in choices],
            [
                ("trunk", "branch", "master"),
                ("v1.0", "tag", "v1.0"),
                ("v1.1", "tag", "v1.1"),
                ("scratch", "detached", commit),
            ],
        )


class WorktreeUpstreamTests(unittest.TestCase):
    def test_existing_branch_worktree_refreshes_origin_upstream(self) -> None:
        with TemporaryDirectory() as directory:
            repo_root = Path(directory)
            bare_dir = repo_root / "worktree.git"
            bare_dir.mkdir()
            target = repo_root / "feature"
            (target / ".git").mkdir(parents=True)
            choice = project_picker.WorktreeChoice(
                "feature  [branch: feature]",
                target,
                "branch",
                "feature",
                True,
            )

            with (
                patch.object(project_picker, "remote_branch_exists", return_value=True),
                patch.object(
                    project_picker,
                    "run",
                    return_value=Mock(returncode=0, stdout="", stderr=""),
                ) as run,
            ):
                result = project_picker.ensure_worktree(repo_root, choice)

        self.assertTrue(result)
        run.assert_called_once_with(
            [
                "git",
                "-C",
                str(target),
                "branch",
                "--set-upstream-to",
                "origin/feature",
                "feature",
            ]
        )


if __name__ == "__main__":
    unittest.main()
