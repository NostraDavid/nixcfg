# ruff: noqa: S603, S607
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


class StarshipStatusTests(unittest.TestCase):
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
