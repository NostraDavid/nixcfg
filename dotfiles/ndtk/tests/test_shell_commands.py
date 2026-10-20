from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

NDTK = Path(__file__).resolve().parents[1]
PYLC = NDTK / ".local/bin/pylc.sh"
FOLDER_COUNT = NDTK / ".local/bin/folder_count.sh"


def test_clip_routes_input_and_preserves_backend_errors() -> None:
    shell = shutil.which("sh")
    cat = shutil.which("cat")
    assert shell is not None and cat is not None
    payload = "héllo\nsecond line without trailing newline"
    for system, wayland, display, backend, status in [
        ("Darwin", "", "", "pbcopy", 0),
        ("Linux", "wayland-0", ":0", "wl-copy", 0),
        ("Linux", "", ":0", "xclip", 0),
        ("Linux", "", ":0", "xclip", 7),
        ("Linux", "", "", "", 1),
        ("Linux", "", ":0", "", 1),
        ("Linux", "wayland-0", "", "", 1),
    ]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = {"uname": f"printf '%s\\n' '{system}'"}
            for name in ("pbcopy", "wl-copy", "xclip"):
                if not backend:
                    continue
                commands[name] = (
                    f"printf '%s\\n' '{name}' \"$@\" >&2\n'{cat}'\nexit {status}"
                )
            for name, body in commands.items():
                command = root / name
                command.write_text(f"#!{shell}\n{body}\n")
                command.chmod(0o755)
            result = subprocess.run(  # noqa: S603
                [shell, str(NDTK / ".local/bin/clip.sh")],
                env={
                    **os.environ,
                    "PATH": directory,
                    "WAYLAND_DISPLAY": wayland,
                    "DISPLAY": display,
                },
                input=payload,
                capture_output=True,
                text=True,
                check=False,
            )
        assert result.returncode == status, result.stderr
        if backend:
            assert result.stdout == payload
            expected = backend + "\n"
            if backend == "xclip":
                expected += "-selection\nclipboard\n"
            assert result.stderr == expected
        else:
            assert "no clipboard available" in result.stderr


def run(script: Path, cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(  # noqa: S603 - tests invoke fixed repository scripts with explicit argv
        [str(script), *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
    )


def test_pylc_counts_source_files_and_sorts_results() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "src/nested").mkdir(parents=True)
        (root / ".venv/src").mkdir(parents=True)
        (root / "venv/src").mkdir(parents=True)
        (root / "src/__pycache__").mkdir()
        (root / "src/main.py").write_text("a = 1\nb = 2\n")
        (root / "src/nested/other.py").write_text("c = 3\n")
        (root / ".venv/src/ignored.py").write_text("d = 4\n")
        (root / "venv/src/ignored.py").write_text("e = 5\n")
        (root / "src/__pycache__/ignored.py").write_text("f = 6\n")

        result = run(PYLC, root, "--sort-desc")

    assert result.returncode == 0, result.stderr
    assert "     2 ./src/main.py" in result.stdout
    assert "     1 ./src/nested/other.py" in result.stdout
    assert "ignored.py" not in result.stdout
    assert "     3 TOTAL" in result.stdout


def test_pylc_help_and_unknown_options() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        help_result = run(PYLC, root, "--help")
        unknown_result = run(PYLC, root, "--unknown")

    assert help_result.returncode == 0
    assert "Usage: pylc" in help_result.stdout
    assert unknown_result.returncode == 2
    assert "unknown option" in unknown_result.stdout


def test_folder_count_counts_regular_files_in_non_git_directories() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "alpha/nested").mkdir(parents=True)
        (root / "beta").mkdir()
        (root / "alpha/one.txt").touch()
        (root / "alpha/nested/two.txt").touch()
        (root / "alpha/__pycache__").mkdir()
        (root / "alpha/__pycache__/cache.pyc").touch()
        (root / "beta/one.txt").touch()
        (root / "outside.txt").touch()
        (root / "alpha/nested/__pycache__").mkdir(parents=True)
        (root / "alpha/nested/__pycache__/nested.pyc").touch()
        (root / "alpha/link.txt").symlink_to(root / "outside.txt")

        result = run(FOLDER_COUNT, root)

    assert result.returncode == 0, result.stderr
    assert result.stdout == "2 alpha/\n1 beta/\n"
    assert "1 beta/" in result.stdout
    assert "outside.txt" not in result.stdout


def test_folder_count_honors_git_ignores_and_excludes_symlinks() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "alpha/ignored").mkdir(parents=True)
        (root / "beta").mkdir()
        (root / ".gitignore").write_text("ignored/\n")
        (root / "alpha/one.txt").touch()
        (root / "alpha/two.txt").touch()
        (root / "alpha/ignored/secret.txt").touch()
        (root / "alpha/__pycache__").mkdir()
        (root / "alpha/__pycache__/cache.pyc").touch()
        (root / "beta/one.txt").touch()
        (root / "alpha/nested/__pycache__").mkdir(parents=True)
        (root / "alpha/nested/__pycache__/nested.pyc").touch()
        (root / "alpha/link.txt").symlink_to(root / "beta/one.txt")

        git = shutil.which("git")
        assert git is not None
        subprocess.run([git, "init", "-q"], cwd=root, check=True)  # noqa: S603
        subprocess.run(  # noqa: S603
            [git, "add", "alpha/one.txt", "alpha/__pycache__/cache.pyc"],
            cwd=root,
            check=True,
        )

        result = run(FOLDER_COUNT, root)

    assert result.returncode == 0, result.stderr
    assert result.stdout == "2 alpha/\n1 beta/\n"
    assert "1 beta/" in result.stdout
    assert "secret.txt" not in result.stdout
