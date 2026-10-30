import json
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = (
    Path(__file__).resolve().parents[1] / "features/dotfiles/worktrunk-marketplace.py"
)


class WorktrunkMarketplaceTests(unittest.TestCase):
    def test_preserves_other_plugins_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".agents/plugins/marketplace.json"
            path.parent.mkdir(parents=True)
            path.write_text(
                json.dumps({"name": "personal", "plugins": [{"name": "other"}]})
            )
            with patch("sys.argv", [str(SCRIPT), directory]):
                runpy.run_path(str(SCRIPT), run_name="__main__")
            first = path.read_text()
            with patch("sys.argv", [str(SCRIPT), directory]):
                runpy.run_path(str(SCRIPT), run_name="__main__")
            self.assertEqual(path.read_text(), first)
            self.assertEqual(
                [p["name"] for p in json.loads(first)["plugins"]],
                ["other", "worktrunk"],
            )

    def test_does_not_replace_a_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".agents/plugins/marketplace.json"
            path.parent.mkdir(parents=True)
            target = Path(directory) / "marketplace.json"
            target.write_text('{"name":"personal","plugins":[]}')
            path.symlink_to(target)
            with (
                patch("sys.argv", [str(SCRIPT), directory]),
                self.assertRaises(SystemExit),
            ):
                runpy.run_path(str(SCRIPT), run_name="__main__")
            self.assertTrue(path.is_symlink())
            self.assertEqual(target.read_text(), '{"name":"personal","plugins":[]}')


if __name__ == "__main__":
    unittest.main()
