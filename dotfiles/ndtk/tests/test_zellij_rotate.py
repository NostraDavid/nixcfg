"""Check quarter turns using stable pane IDs and terminal cell coordinates."""

import runpy
import unittest
from pathlib import Path

module = runpy.run_path(str(Path(__file__).parents[1] / ".local/bin/zellij-rotate.py"))
Pane = module["Pane"]
plan = module["rotation_plan"]


class RotationTests(unittest.TestCase):
    def test_quarter_turn_and_inverse_keep_terminal_identity(self) -> None:
        left = [Pane(7, 0, 1, 60, 38), Pane(9, 60, 1, 60, 19), Pane(3, 60, 20, 60, 19)]
        self.assertEqual(plan(left, True, None), ("main-top", [7, 3, 9], None))
        top = [Pane(7, 0, 1, 120, 19), Pane(3, 0, 20, 60, 19), Pane(9, 60, 20, 60, 19)]
        self.assertEqual(plan(top, False, None), ("main-left", [7, 9, 3], None))
        for focus in (9, 3):
            self.assertEqual(plan(left, True, focus), ("main-left-flat", [3, 9], 7))
        self.assertIsNone(plan(left, True, 7))

    def test_pair_turn_preserves_a_manually_sized_neighbour(self) -> None:
        panes = [Pane(1, 0, 1, 80, 38), Pane(2, 80, 1, 40, 19), Pane(3, 80, 20, 40, 19)]
        self.assertIsNone(plan(panes, True, 3))


if __name__ == "__main__":
    unittest.main()
