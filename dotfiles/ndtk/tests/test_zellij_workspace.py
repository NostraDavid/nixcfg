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
import socket
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
        self.assertEqual(
            MODULE["matching_sessions"](PREFIX, sessions, 103),
            [PREFIX + "2028-01-01T00:00:00", newer, older],
        )
        self.assertEqual(MODULE["matching_sessions"](PREFIX, ["ghostty"], 103), [])

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
                MODULE["workspace_prefix"](Path("/repos/nixcfg/trunk/src")),
                (PREFIX, "/repos/nixcfg/trunk"),
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
                ("vscode_example-example_", "/repos/example"),
            )
        with patch.object(
            sp, "run", return_value=sp.CompletedProcess([], 128, "", "not a repository")
        ):
            self.assertEqual(
                MODULE["workspace_prefix"](Path("/workspace")),
                ("vscode_workspace_", "/workspace"),
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
                    MODULE["main"].__globals__,
                    {"workspace_prefix": lambda _: (PREFIX, "/repos/nixcfg/trunk")},
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
                self.assertRegex(
                    argv[3],
                    PREFIX
                    + r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}$",
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
            self.assertRegex(
                output.getvalue().strip(),
                app + r"_\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}$",
            )
            execute.assert_not_called()

    def test_name_shortening_preserves_details_in_priority_order(self) -> None:
        timestamp = dt.datetime.fromisoformat("2026-10-22T12:34:56.123456+02:00")
        for expected in (
            "vscode_project-work_2026-10-22T12:34:56.123+02:00",
            "vscode_prjct-wrk_2026-10-22T12:34:56.123+02:00",
            "vscode_prjct-wrk_2026-10-22T12:34:56.123",
            "vscode_prjct-wrk_2026-10-22T12:34:56",
            "vscode_prjc_2026-10-22T12:34:56",
        ):
            with self.subTest(expected=expected):
                self.assertEqual(
                    MODULE["format_session_name"](
                        "vscode_project-work_", timestamp, len(expected)
                    ),
                    expected,
                )

    def test_unicode_names_fit_real_socket_paths(self) -> None:
        timestamp = dt.datetime.fromisoformat("2026-10-22T12:34:56.123+02:00")
        with tempfile.TemporaryDirectory(dir="/tmp") as directory:
            root = Path(directory) / "sockets"
            socket_dir = root / "contract_version_1"
            socket_dir.mkdir(parents=True)
            with patch.dict(os.environ, {"ZELLIJ_SOCKET_DIR": str(root)}):
                budget = MODULE["socket_name_budget"]()
            prefix = "vscode_" + "项目" * 40 + "-trunk_"
            name = MODULE["format_session_name"](prefix, timestamp, budget)
            path = socket_dir / name
            self.assertLessEqual(len(os.fsencode(path)), 103)
            self.assertTrue(name.endswith("2026-10-22T12:34:56"))
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
                listener.bind(str(path))
            self.assertEqual(
                MODULE["matching_sessions"](prefix, [name], budget), [name]
            )

    def test_socket_directory_must_leave_room_for_a_session_name(self) -> None:
        with patch.dict(os.environ, {"ZELLIJ_SOCKET_DIR": "/custom/" + "x" * 100}):
            budget = MODULE["socket_name_budget"]()
        with self.assertRaisesRegex(RuntimeError, "set ZELLIJ_SOCKET_DIR"):
            MODULE["format_session_name"](
                PREFIX, dt.datetime.fromisoformat("2026-10-22T12:34:56+02:00"), budget
            )

    def test_shortened_session_from_another_project_is_not_reused(self) -> None:
        cache = Path(os.environ["XDG_CACHE_HOME"])
        session = "vscode_prjct_2026-10-22T12:34:56"
        (cache / f"{session}.lock").write_text("/repos/project-a/trunk")
        with (
            patch.object(
                sp,
                "run",
                return_value=sp.CompletedProcess(
                    [], 0, "CLIENT_ID ZELLIJ_PANE_ID RUNNING_COMMAND\n", ""
                ),
            ),
            contextlib.ExitStack() as stack,
        ):
            for reservation in (None, stack):
                self.assertFalse(
                    MODULE["reserve_detached_session"](
                        session, "/repos/project-b/trunk", cache, reservation
                    )
                )
                self.assertTrue(
                    MODULE["reserve_detached_session"](
                        session, "/repos/project-a/trunk", cache, reservation
                    )
                )

    def test_macos_uses_short_socket_directory_and_preserves_overrides(self) -> None:
        long_tmp = "/var/folders/n1/ktv6x7d50yb_n60s9gjny10m0000gp/T/"
        for platform, override, expected in (
            ("darwin", None, "/tmp/zellij-502"),  # noqa: S108 - Expected socket path, never created by this test.
            ("darwin", "/custom/sockets", "/custom/sockets"),
            ("linux", None, None),
        ):
            for app in ("vscode", "ghostty", "alacritty"):
                environment = dict(os.environ, TMPDIR=long_tmp)
                environment.pop("ZELLIJ_SOCKET_DIR", None)
                if override is not None:
                    environment["ZELLIJ_SOCKET_DIR"] = override

                def execute(
                    argv: list[str],
                    *_: object,
                    expected: str | None = expected,
                    platform: str = platform,
                    **__: object,
                ) -> sp.CompletedProcess[str]:
                    self.assertEqual(os.environ.get("ZELLIJ_SOCKET_DIR"), expected)
                    if argv[0] == "git":
                        return sp.CompletedProcess(
                            argv,
                            0,
                            "/repos/nixcfg/trunk\n/repos/nixcfg/worktree.git\n",
                            "",
                        )
                    if platform == "darwin":
                        socket = f"{expected}/contract_version_1/{argv[-1]}"
                        self.assertLessEqual(len(socket.encode()), 103)
                    return sp.CompletedProcess(argv, 0, "", "")

                with (
                    self.subTest(platform=platform, override=override, app=app),
                    patch.dict(os.environ, environment, clear=True),
                    patch("sys.platform", platform),
                    patch("os.getuid", return_value=502),
                    patch("sys.argv", ["zellij-workspace", "--new", app]),
                    patch.object(sp, "run", side_effect=execute),
                    patch("os.execvp", side_effect=lambda _, argv: execute(argv)),
                ):
                    with self.assertRaises(SystemExit) as stopped:
                        runpy.run_path(MODULE["__file__"], run_name="__main__")
                    self.assertEqual(stopped.exception.code, 0)

    def test_new_session_waits_if_name_is_reserved(self) -> None:
        now = dt.datetime(2026, 10, 22, 12, 0, 0, tzinfo=dt.UTC).astimezone()
        later = now + dt.timedelta(seconds=1)
        cache = Path(os.environ["XDG_CACHE_HOME"]) / "zellij-workspace"
        cache.mkdir()
        for app, prefix in (("vscode", PREFIX), ("ghostty", "ghostty_")):
            (cache / f"{prefix}{now.isoformat(timespec='milliseconds')}.lock").touch()
            with (
                self.subTest(app=app),
                patch.dict(
                    MODULE["main"].__globals__,
                    {"workspace_prefix": lambda _: (PREFIX, "/repos/nixcfg/trunk")},
                ),
                patch("sys.argv", ["zellij-workspace", app, "--new"]),
                patch.object(dt, "datetime") as clock,
                patch("time.sleep") as sleep,
                patch.object(sp, "run") as execute,
                patch("os.execvp") as replace,
            ):
                clock.now.side_effect = [now, later]
                MODULE["main"]()
                sleep.assert_called_once_with(0.1)
                if app == "vscode":
                    self.assertEqual(
                        execute.call_args.args[0][-1],
                        prefix + later.isoformat(timespec="milliseconds"),
                    )
                else:
                    self.assertEqual(
                        replace.call_args.args[1][-1],
                        prefix + later.isoformat(timespec="milliseconds"),
                    )

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
                MODULE["main"].__globals__,
                {"workspace_prefix": lambda _: (PREFIX, "/repos/nixcfg/trunk")},
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
            self.assertFalse(
                MODULE["reserve_detached_session"](session, "", cache, stack)
            )
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
            self.assertTrue(
                MODULE["reserve_detached_session"](session, "", cache, stack)
            )

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
                    MODULE["reserve_detached_session"](
                        "session", "", Path(os.environ["XDG_CACHE_HOME"]), stack
                    )
                )

    def test_listing_error_does_not_start_a_session(self) -> None:
        with (
            patch.dict(
                MODULE["main"].__globals__,
                {"workspace_prefix": lambda _: (PREFIX, "/repos/nixcfg/trunk")},
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
