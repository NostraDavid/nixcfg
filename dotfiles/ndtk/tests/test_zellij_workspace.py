#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# ///

"""Check session selection and the launcher without touching user sessions."""

import contextlib
import fcntl
import io
import os
import runpy
import socket
import subprocess as sp
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE = runpy.run_path(
    str(Path(__file__).parents[1] / ".local/bin/zellij-workspace.py")
)
BASE = "ws_nixcfg-trunk"
ROOT = "/repos/nixcfg/trunk"


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

    def launch(self, *args: str, listing: str = "", clients: str = "") -> str:
        def run(argv: list[str], **_: object) -> sp.CompletedProcess[str]:
            if argv[0] == "git":
                return sp.CompletedProcess(
                    argv, 0, f"{ROOT}\n/repos/nixcfg/worktree.git\n", ""
                )
            if "list-sessions" in argv:
                return sp.CompletedProcess(argv, 0, listing, "")
            if "list-clients" in argv:
                return sp.CompletedProcess(argv, 0, clients, "")
            self.assertEqual(argv[:3], ["zellij", "attach", "--create"])
            attached.append(argv[-1])
            return sp.CompletedProcess(argv, 0, "", "")

        attached = []
        output = io.StringIO()
        with (
            patch("sys.argv", ["zellij-workspace", *args]),
            patch.object(sp, "run", side_effect=run),
            contextlib.redirect_stdout(output),
        ):
            self.assertEqual(MODULE["main"](), 0)
        if "--dry-run" in args:
            self.assertEqual(attached, [])
            return output.getvalue().strip()
        self.assertEqual(len(attached), 1)
        return attached[0]

    def test_manual_launch_restores_same_slot_across_terminals_and_dates(self) -> None:
        self.assertEqual(self.launch(), BASE)
        saved = f"{BASE} [Created 3days ago] (EXITED - attach to resurrect)"
        for app in ("vscode", "alacritty", "ghostty"):
            self.assertEqual(self.launch(app, listing=saved), BASE)
        self.assertEqual(self.launch("--new", listing=saved), f"{BASE}-2")

    def test_running_sessions_reused_only_if_detached(self) -> None:
        self.launch()
        listing = f"{BASE} [Created 1h ago]"
        header = "CLIENT_ID  ZELLIJ_PANE_ID RUNNING_COMMAND\n"
        self.assertEqual(self.launch(listing=listing, clients=header), BASE)
        self.assertEqual(
            self.launch(listing=listing, clients=header + "1 terminal_0 bash\n"),
            BASE + "-2",
        )
        self.assertEqual(
            self.launch(listing=listing, clients="unexpected"), BASE + "-2"
        )

    def test_active_legacy_session_keeps_its_worktree(self) -> None:
        old = "vscode_nxcfg-trnk_2026-10-22T12:34:56"
        cache = Path(os.environ["XDG_CACHE_HOME"]) / "zellij-workspace"
        cache.mkdir()
        lease = cache / f"{old}.lock"
        lease.write_text(ROOT)
        listing = f"{old} [Created 2days ago]"
        header = "CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND\n"
        self.assertEqual(self.launch(listing=listing, clients=header), old)
        lease.write_text("/elsewhere/nixcfg/trunk")
        self.assertEqual(self.launch(listing=listing, clients=header), BASE)
        self.assertEqual(
            self.launch(listing=listing + " (EXITED - attach to resurrect)"), BASE
        )

    def test_slot_collisions_and_simultaneous_opens(self) -> None:
        cache = Path(os.environ["XDG_CACHE_HOME"]) / "zellij-workspace"
        cache.mkdir()
        path = cache / f"{BASE}.lock"
        path.write_text("/another/nixcfg/trunk")
        self.assertEqual(self.launch(), BASE + "-2")
        path.write_text(ROOT)
        with path.open("r+") as lease:
            fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(self.launch(), BASE + "-2")
            self.assertEqual(self.launch("--dry-run"), BASE + "-2")
        self.assertEqual(self.launch(), BASE)
        self.assertEqual(self.launch("--new"), BASE + "-3")

    def test_dry_run_does_not_create_files_or_claim_an_unowned_session(self) -> None:
        cache = Path(os.environ["XDG_CACHE_HOME"]) / "zellij-workspace"
        self.assertEqual(self.launch("--dry-run"), BASE)
        self.assertEqual(
            self.launch("--dry-run", listing=f"{BASE} [Created 1s ago]"), BASE + "-2"
        )
        self.assertFalse(cache.exists())

    def test_worktree_subfolders_and_non_git_directories(self) -> None:
        with patch.object(
            sp,
            "run",
            return_value=sp.CompletedProcess(
                [], 0, f"{ROOT}\n/repos/nixcfg/worktree.git\n", ""
            ),
        ):
            self.assertEqual(
                MODULE["workspace"](Path(ROOT) / "src"), ("nixcfg-trunk", ROOT)
            )
        with patch.object(sp, "run", return_value=sp.CompletedProcess([], 128, "", "")):
            self.assertEqual(
                MODULE["workspace"](Path("/elsewhere/example")),
                ("example", "/elsewhere/example"),
            )

    def test_shortening_keeps_numeric_slot_and_utf8_within_socket_budget(self) -> None:
        name = MODULE["session_name"]
        self.assertEqual(name("project", 2, len("ws_prjct-2")), "ws_prjct-2")
        with tempfile.TemporaryDirectory(dir="/tmp") as directory:
            root = Path(directory) / "sockets"
            socket_dir = root / "contract_version_1"
            socket_dir.mkdir(parents=True)
            with patch.dict(os.environ, {"ZELLIJ_SOCKET_DIR": str(root)}):
                budget = MODULE["socket_name_budget"]()
            value = name("项目" * 40, 12, budget)
            self.assertTrue(value.endswith("-12"))
            path = socket_dir / value
            self.assertLessEqual(len(os.fsencode(path)), 103)
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
                listener.bind(str(path))
        with self.assertRaisesRegex(RuntimeError, "ZELLIJ_SOCKET_DIR"):
            name("project", 1, 2)

    def test_unresponsive_and_failed_listings(self) -> None:
        with patch.object(sp, "run", side_effect=sp.TimeoutExpired("zellij", 10)):
            self.assertFalse(MODULE["detached"](BASE))
        with patch.object(
            sp,
            "run",
            return_value=sp.CompletedProcess(
                [], 1, "", "No active zellij sessions found.\n"
            ),
        ):
            self.assertEqual(MODULE["list_sessions"](), (set(), set()))
        for rc, out, err in [
            (1, "", "permission denied"),
            (2, "", "listing failed"),
            (0, "invalid row", ""),
        ]:
            with (
                patch.object(
                    sp, "run", return_value=sp.CompletedProcess([], rc, out, err)
                ),
                self.assertRaises(RuntimeError),
            ):
                MODULE["list_sessions"]()

    def test_macos_socket_root_respects_override(self) -> None:
        for override in (None, "/custom/sockets"):
            env = dict(os.environ, TMPDIR="/var/folders/" + "x" * 100)
            env.pop("ZELLIJ_SOCKET_DIR", None)
            if override:
                env["ZELLIJ_SOCKET_DIR"] = override

            def run(
                argv: list[str], *, expected: str | None = override, **_: object
            ) -> sp.CompletedProcess[str]:
                self.assertEqual(
                    os.environ["ZELLIJ_SOCKET_DIR"],
                    expected or "/tmp/zellij-502",  # noqa: S108 - Expected Zellij socket path.
                )
                if argv[0] == "git":
                    return sp.CompletedProcess(argv, 128, "", "not a git repository")
                return sp.CompletedProcess(argv, 0, "", "")

            with (
                patch.dict(os.environ, env, clear=True),
                patch("sys.platform", "darwin"),
                patch("os.getuid", return_value=502),
                patch("sys.argv", ["zellij-workspace", "--new"]),
                patch.object(sp, "run", side_effect=run),
                self.assertRaises(SystemExit) as stopped,
            ):
                runpy.run_path(MODULE["__file__"], run_name="__main__")
            self.assertEqual(stopped.exception.code, 0)


if __name__ == "__main__":
    unittest.main()
