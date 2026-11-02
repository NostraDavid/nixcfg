# ruff: noqa: S603, S607
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


class StarshipStatusTests(unittest.TestCase):
    def test_worktree_prompt_status_spacing_and_separator_colors(self) -> None:
        config = (
            Path(__file__).resolve().parents[2]
            / "starship-1.23.0/.config/starship.toml"
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root / "repo")], check=True)
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(root / "repo"),
                    "-c",
                    "core.hooksPath=/dev/null",
                    "-c",
                    "user.name=Test",
                    "-c",
                    "user.email=test@example.invalid",
                    "commit",
                    "--allow-empty",
                    "-qm",
                    "test: initial",
                ],
                check=True,
            )
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(root / "repo"),
                    "worktree",
                    "add",
                    "-qb",
                    "test",
                    str(root / "worktree"),
                ],
                check=True,
            )
            tracked = root / "worktree" / "tracked"
            tracked.write_text("initial\n")
            subprocess.run(["git", "add", "tracked"], cwd=tracked.parent, check=True)
            subprocess.run(
                [
                    "git",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "-c",
                    "user.name=Test",
                    "-c",
                    "user.email=test@example.invalid",
                    "commit",
                    "-qm",
                    "test: tracked",
                ],
                cwd=tracked.parent,
                check=True,
            )
            subprocess.run(
                ["git", "branch", "--unset-upstream"], cwd=tracked.parent, check=True
            )
            env = os.environ | {
                "STARSHIP_CONFIG": str(config),
                "VIRTUAL_ENV": str(root / "example"),
                "STARSHIP_SHELL": "",
                "PWD": str(root / "worktree"),
            }
            for dirty in (False, True):
                if dirty:
                    (root / "repo" / "untracked").touch()
                result = subprocess.run(
                    ["starship", "prompt"],
                    cwd=root / "repo",
                    env=env | {"PWD": str(root / "repo")},
                    capture_output=True,
                    text=True,
                    check=True,
                ).stdout
                plain = re.sub(r"\x1b\[[0-9;]*m", "", result)
                self.assertRegex(plain, r" \S+ " + ("… 1 " if dirty else "") + "")
            for state, expected in (
                ("clean", "wt "),
                ("modified", "wt ✚ 1 "),
                ("staged", "wt ● 1 "),
                ("both", "wt ● 1 ✚ 1 "),
                ("untracked", "wt ● 1 ✚ 1 … 1 "),
            ):
                if state in ("modified", "both"):
                    tracked.write_text(f"{state}\n")
                elif state == "staged":
                    subprocess.run(
                        ["git", "add", "tracked"], cwd=tracked.parent, check=True
                    )
                elif state == "untracked":
                    (root / "worktree" / "untracked").touch()
                result = subprocess.run(
                    ["starship", "prompt"],
                    cwd=root / "worktree",
                    env=env,
                    capture_output=True,
                    text=True,
                    check=True,
                ).stdout
                self.assertIn("\x1b[48;2;48;48;48;38;2;95;175;215m", result)
                self.assertIn("\x1b[48;2;88;88;88;38;2;48;48;48m", result)
                with self.subTest(state=state):
                    plain = re.sub(r"\x1b\[[0-9;]*m", "", result)
                    self.assertIn(expected, plain)

    def test_bare_repository_has_no_worktree_status(self) -> None:
        config = (
            Path(__file__).resolve().parents[2]
            / "starship-1.23.0/.config/starship.toml"
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root / "source")], check=True)
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(root / "source"),
                    "-c",
                    "core.hooksPath=/dev/null",
                    "-c",
                    "user.name=Test",
                    "-c",
                    "user.email=test@example.invalid",
                    "commit",
                    "--allow-empty",
                    "-qm",
                    "test: initial",
                ],
                check=True,
            )
            (root / "container").mkdir()
            subprocess.run(
                [
                    "git",
                    "clone",
                    "-q",
                    "--bare",
                    str(root / "source"),
                    str(root / "container/.git"),
                ],
                check=True,
            )
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(root / "container"),
                    "config",
                    "extensions.worktreeConfig",
                    "true",
                ],
                check=True,
            )
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(root / "container"),
                    "config",
                    "--worktree",
                    "core.bare",
                    "true",
                ],
                check=True,
            )
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(root / "container"),
                    "config",
                    "--local",
                    "--unset",
                    "core.bare",
                ],
                check=True,
            )
            (root / "source" / "untracked").touch()
            env = os.environ | {"STARSHIP_CONFIG": str(config)}
            for path, expected in (
                (root / "container", False),
                (root / "source", True),
            ):
                result = subprocess.run(
                    ["starship", "module", "custom.safe_git_status"],
                    cwd=path,
                    env=env,
                    capture_output=True,
                    text=True,
                    check=True,
                )
                self.assertEqual("…" in result.stdout, expected)


if __name__ == "__main__":
    unittest.main()
