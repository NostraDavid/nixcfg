from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

SCRIPT = Path(__file__).resolve().parents[1] / ".local/bin/apply_peacock_color.py"
PROJECT_COLOR = SCRIPT.with_name("project_color.py")


class PeacockColorTests(unittest.TestCase):
    def run_script(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_auto_color_preserves_unmanaged_settings(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory) / "example"
            (root / "worktree.git").mkdir(parents=True)
            worktree = root / "trunk"
            settings_path = worktree / ".vscode" / "settings.json"
            settings_path.parent.mkdir(parents=True)
            settings_path.write_text(
                json.dumps(
                    {
                        "editor.fontSize": 14,
                        "workbench.colorCustomizations": {
                            "editor.background": "#222222",
                            "statusBar.background": "#000000",
                        },
                        "peacock.color": "old",
                    }
                )
            )

            result = self.run_script("apply", "auto", str(worktree), "--yes")
            self.assertEqual(result.returncode, 0, result.stderr)
            settings = json.loads(settings_path.read_text())
            expected = (
                subprocess.run(
                    [sys.executable, str(PROJECT_COLOR), "example"],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                .stdout.strip()
                .lower()
            )
            self.assertEqual(settings["peacock.remoteColor"], expected)
            self.assertEqual(settings["editor.fontSize"], 14)
            colors = settings["workbench.colorCustomizations"]
            self.assertEqual(colors["editor.background"], "#222222")
            self.assertEqual(colors["statusBar.background"], expected)
            self.assertNotIn("peacock.color", settings)

            before = settings_path.read_bytes()
            self.assertEqual(
                self.run_script("apply", "auto", str(worktree), "--yes").returncode, 0
            )
            self.assertEqual(settings_path.read_bytes(), before)

    def test_check_and_dry_run_do_not_write(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            check = self.run_script("check", "--repo", str(root))
            self.assertEqual(check.returncode, 0, check.stderr)
            self.assertEqual(check.stdout, "OK\n")
            preview = self.run_script("apply", "#123456", str(root), "--dry-run")
            self.assertEqual(preview.returncode, 0, preview.stderr)
            self.assertIn('"peacock.remoteColor": "#123456"', preview.stdout)
            self.assertFalse((root / ".vscode").exists())

    def test_invalid_json_is_left_untouched(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory)
            settings_path = root / ".vscode" / "settings.json"
            settings_path.parent.mkdir()
            settings_path.write_text("{invalid")
            result = self.run_script("apply", "auto", str(root), "--yes")
            self.assertEqual(result.returncode, 1)
            self.assertIn("invalid JSON", result.stderr)
            self.assertEqual(settings_path.read_text(), "{invalid")


if __name__ == "__main__":
    unittest.main()
