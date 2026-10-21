#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# ///

"""Check session selection and the launcher without touching user sessions."""

import contextlib
import datetime as dt
import fcntl
import io
import os
import runpy
import subprocess as sp
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE = runpy.run_path(
    str(Path(__file__).parents[1] / ".local/bin/zellij-workspace.py")
)
PREFIX = "vscode_nixcfg-trunk_"


class SessionTests(unittest.TestCase):
    def setUp(self) -> None:
        cache = self.enterContext(tempfile.TemporaryDirectory())
        self.enterContext(patch.dict(os.environ, {"XDG_CACHE_HOME": cache}))

    def test_scrollback_ctrl_z_exits_and_preserves_unsaved_edits(self) -> None:
        editor = Path(__file__).parents[1] / ".local/bin/zellij-scrollback.sh"
        command = [str(editor), "--headless", "-u", "NONE", "-i", "NONE", "-n"]
        for mode in ("", "v"):
            result = sp.run(  # noqa: S603 - Run the repository editor with literal test keys.
                [
                    *command,
                    "-c",
                    "vsplit",
                    "-c",
                    f'execute "normal {mode}\\<C-z>"',
                    "-c",
                    "cquit 1",
                ],
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
        result = sp.run(  # noqa: S603 - Edits are confined to an unnamed test buffer.
            [
                *command,
                "-c",
                "normal iX",
                "-c",
                "vnew",
                "-c",
                'silent! execute "normal \\<C-z>"',
                "-c",
                "lua assert(#vim.fn.getbufinfo({bufmodified=1}) == 1)",
                "-c",
                "qa!",
            ],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_latest_timestamp_respects_offsets_and_ignores_other_worktrees(
        self,
    ) -> None:
        older = PREFIX + "2026-10-21T15:00:00.123+02:00"
        newer = PREFIX + "2026-10-21T14:30:00.123+00:00"
        sessions = [
            newer,
            older,
            "vscode_other-trunk_2027-01-01T00:00:00Z",
            PREFIX + "invalid",
            PREFIX + "2028-01-01T00:00:00",
        ]
        self.assertEqual(MODULE["matching_sessions"](PREFIX, sessions), [newer, older])
        self.assertEqual(MODULE["matching_sessions"](PREFIX, ["ghostty"]), [])

    def test_worktree_and_subdirectory_share_prefix(self) -> None:
        with patch.object(
            sp,
            "run",
            return_value=sp.CompletedProcess(
                [],
                0,
                "/repos/nixcfg/trunk\n/repos/nixcfg/worktree.git\n",
                "",
            ),
        ):
            self.assertEqual(
                MODULE["workspace_prefix"](Path("/repos/nixcfg/trunk/src")), PREFIX
            )

    def test_regular_checkout_and_non_git_directory(self) -> None:
        with patch.object(
            sp,
            "run",
            return_value=sp.CompletedProcess(
                [],
                0,
                "/repos/example\n/repos/example/.git\n",
                "",
            ),
        ):
            self.assertEqual(
                MODULE["workspace_prefix"](Path("/repos/example")),
                "vscode_example-example_",
            )
        with patch.object(
            sp, "run", return_value=sp.CompletedProcess([], 128, "", "not a repository")
        ):
            self.assertEqual(
                MODULE["workspace_prefix"](Path("/workspace")), "vscode_workspace_"
            )

    def test_vscode_reuses_session_and_new_profile_creates_another(self) -> None:
        existing = PREFIX + "2026-10-21T14:30:52.123+02:00"

        def run(argv: list[str], **_: object) -> sp.CompletedProcess[str]:
            output = (
                "CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND\n"
                if "list-clients" in argv
                else existing + "\n"
            )
            return sp.CompletedProcess(argv, 0, output, "")

        for extra in ([], ["--new"]):
            with (
                patch.dict(
                    MODULE["main"].__globals__, {"workspace_prefix": lambda _: PREFIX}
                ),
                patch("sys.argv", ["zellij-workspace", "vscode", *extra]),
                patch.object(
                    sp,
                    "run",
                    side_effect=run,
                ) as execute,
            ):
                MODULE["main"]()
            argv = execute.call_args.args[0]
            self.assertEqual(argv[:3], ["zellij", "attach", "--create"])
            if extra:
                self.assertNotEqual(argv[3], existing)
                self.assertIsNotNone(
                    dt.datetime.fromisoformat(argv[3].removeprefix(PREFIX)).tzinfo
                )
            else:
                self.assertEqual(argv[3], existing)

    def test_terminal_dry_run_has_iso_timestamp_and_never_starts_zellij(self) -> None:
        for app in ("ghostty", "alacritty"):
            output = io.StringIO()
            with (
                patch("sys.argv", ["zellij-workspace", app, "--dry-run"]),
                patch("os.execvp") as execute,
                contextlib.redirect_stdout(output),
            ):
                MODULE["main"]()
            self.assertIsNotNone(
                dt.datetime.fromisoformat(
                    output.getvalue().strip().removeprefix(app + "_")
                ).tzinfo
            )
            execute.assert_not_called()

    def test_attached_session_is_not_reused(self) -> None:
        existing = PREFIX + "2026-10-21T14:30:52.123+02:00"

        def run(argv: list[str], **_: object) -> sp.CompletedProcess[str]:
            output = (
                "CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND\n1 terminal_0 N/A\n"
                if "list-clients" in argv
                else existing + "\n"
            )
            return sp.CompletedProcess(argv, 0, output, "")

        with (
            patch.dict(
                MODULE["main"].__globals__, {"workspace_prefix": lambda _: PREFIX}
            ),
            patch("sys.argv", ["zellij-workspace", "vscode", "--dry-run"]),
            patch.object(sp, "run", side_effect=run),
            contextlib.redirect_stdout(io.StringIO()) as output,
        ):
            MODULE["main"]()
        self.assertNotEqual(output.getvalue().strip(), existing)

    def test_detached_session_reserved_by_another_launcher_is_not_reused(self) -> None:
        session = PREFIX + "2026-10-21T14:30:52.123+02:00"
        cache = Path(os.environ["XDG_CACHE_HOME"])
        with (
            (cache / f"{session}.lock").open("a") as lease,
            contextlib.ExitStack() as stack,
            patch.object(
                sp,
                "run",
                return_value=sp.CompletedProcess(
                    [],
                    0,
                    "CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND\n",
                    "",
                ),
            ),
        ):
            fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertFalse(MODULE["reserve_detached_session"](session, cache, stack))
        with (
            contextlib.ExitStack() as stack,
            patch.object(
                sp,
                "run",
                return_value=sp.CompletedProcess(
                    [],
                    0,
                    "CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND\n",
                    "",
                ),
            ),
        ):
            self.assertTrue(MODULE["reserve_detached_session"](session, cache, stack))

    def test_unresponsive_or_unknown_session_is_not_reused(self) -> None:
        for result in (
            sp.TimeoutExpired("zellij", 10),
            sp.CompletedProcess([], 1, "", "session vanished"),
            sp.CompletedProcess([], 0, "unexpected output", ""),
        ):
            with (
                self.subTest(result=result),
                contextlib.ExitStack() as stack,
                patch.object(sp, "run", side_effect=[result]),
            ):
                self.assertFalse(
                    MODULE["reserve_detached_session"]("session", None, stack)
                )

    def test_listing_error_does_not_start_a_session(self) -> None:
        with (
            patch.dict(
                MODULE["main"].__globals__, {"workspace_prefix": lambda _: PREFIX}
            ),
            patch("sys.argv", ["zellij-workspace", "vscode"]),
            patch.object(
                sp, "run", return_value=sp.CompletedProcess([], 2, "", "listing failed")
            ),
            patch("os.execvp") as execute,
            self.assertRaisesRegex(RuntimeError, "listing failed"),
        ):
            MODULE["main"]()
        execute.assert_not_called()


if __name__ == "__main__":
    unittest.main()
