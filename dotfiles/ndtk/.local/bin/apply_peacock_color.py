#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# ///

"""Set a stable Peacock-style color for a VS Code worktree."""

from __future__ import annotations

import argparse
import colorsys
import json
import os
import re
import stat
import sys
import tempfile
from pathlib import Path

from project_color import project_color

MANAGED_KEYS = {
    "activityBar.activeBackground",
    "activityBar.background",
    "activityBar.foreground",
    "activityBar.inactiveForeground",
    "activityBarBadge.background",
    "activityBarBadge.foreground",
    "commandCenter.border",
    "commandCenter.foreground",
    "editorGroup.border",
    "panel.border",
    "sideBar.border",
    "sash.hoverBorder",
    "editorError.foreground",
    "editorWarning.foreground",
    "editorInfo.foreground",
    "statusBar.border",
    "statusBar.background",
    "statusBar.foreground",
    "statusBar.debuggingBorder",
    "statusBar.debuggingBackground",
    "statusBar.debuggingForeground",
    "statusBarItem.hoverBackground",
    "statusBarItem.remoteBackground",
    "statusBarItem.remoteForeground",
    "tab.activeBorder",
    "titleBar.activeBackground",
    "titleBar.activeForeground",
    "titleBar.border",
    "titleBar.inactiveBackground",
    "titleBar.inactiveForeground",
}
LIGHT_FOREGROUND = "#e7e7e7"
DARK_FOREGROUND = "#15202b"


def project_name(path: Path) -> str:
    current = path.resolve()
    while True:
        if (current / "worktree.git").is_dir():
            return current.name
        if current.parent == current:
            return path.name
        current = current.parent


def rgb(color: str) -> tuple[int, int, int]:
    return tuple(int(color[index : index + 2], 16) for index in (1, 3, 5))


def hex_color(red: float, green: float, blue: float) -> str:
    return f"#{round(red * 255):02x}{round(green * 255):02x}{round(blue * 255):02x}"


def adjust(color: str, amount: float) -> str:
    red, green, blue = (channel / 255 for channel in rgb(color))
    hue, lightness, saturation = colorsys.rgb_to_hls(red, green, blue)
    return hex_color(
        *colorsys.hls_to_rgb(hue, max(0, min(1, lightness + amount)), saturation)
    )


def is_light(color: str) -> bool:
    red, green, blue = rgb(color)
    return (red * 299 + green * 587 + blue * 114) // 1000 >= 128


def foreground(color: str) -> str:
    return DARK_FOREGROUND if is_light(color) else LIGHT_FOREGROUND


def accent(color: str) -> str:
    red, green, blue = (channel / 255 for channel in rgb(color))
    hue, _, saturation = colorsys.rgb_to_hls(red, green, blue)
    hue = (hue + 1 / 3) % 1
    saturation = max(saturation, 0.5)
    return hex_color(
        *colorsys.hls_to_rgb(hue, 0.3 if is_light(color) else 0.7, saturation)
    )


def peacock_colors(color: str) -> dict[str, str]:
    activity = adjust(color, 0.1)
    activity_foreground = foreground(activity)
    title_foreground = foreground(color)
    badge = accent(activity)
    return {
        "activityBar.activeBackground": activity,
        "activityBar.background": activity,
        "activityBar.foreground": activity_foreground,
        "activityBar.inactiveForeground": f"{activity_foreground}99",
        "activityBarBadge.background": badge,
        "activityBarBadge.foreground": foreground(badge),
        "commandCenter.border": f"{title_foreground}99",
        "sash.hoverBorder": activity,
        "statusBar.background": color,
        "statusBar.foreground": title_foreground,
        "statusBarItem.hoverBackground": adjust(
            color, -0.1 if is_light(color) else 0.1
        ),
        "statusBarItem.remoteBackground": color,
        "statusBarItem.remoteForeground": title_foreground,
        "titleBar.activeBackground": color,
        "titleBar.activeForeground": title_foreground,
        "titleBar.inactiveBackground": f"{color}99",
        "titleBar.inactiveForeground": f"{title_foreground}99",
    }


def read_settings(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    try:
        settings = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid JSON in {path}: {error}") from error
    if not isinstance(settings, dict):
        raise ValueError(f"expected a JSON object in {path}")
    return settings


def updated_settings(settings: dict[str, object], color: str) -> dict[str, object]:
    existing = settings.get("workbench.colorCustomizations")
    customizations = dict(existing) if isinstance(existing, dict) else {}
    customizations = {
        key: value for key, value in customizations.items() if key not in MANAGED_KEYS
    }
    customizations.update(peacock_colors(color))
    return {
        "workbench.colorCustomizations": customizations,
        "peacock.remoteColor": color,
        **{
            key: value
            for key, value in settings.items()
            if key
            not in {
                "workbench.colorCustomizations",
                "peacock.remoteColor",
                "peacock.color",
            }
        },
    }


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        if path.exists():
            temporary.chmod(stat.S_IMODE(path.stat().st_mode))
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("check", help="Check access to workspace settings.")
    check.add_argument("--repo", type=Path, default=Path.cwd())
    apply = commands.add_parser("apply", help="Apply a hex color or 'auto'.")
    apply.add_argument("color")
    apply.add_argument("repo", nargs="?", type=Path, default=Path.cwd())
    apply.add_argument("--dry-run", action="store_true")
    apply.add_argument("--yes", action="store_true")
    args = parser.parse_args(argv)

    repo = args.repo.expanduser().resolve()
    if not repo.is_dir():
        print(f"missing directory: {repo}", file=sys.stderr)
        return 1
    path = repo / ".vscode" / "settings.json"
    try:
        settings = read_settings(path)
        if args.command == "check":
            parent = path.parent if path.parent.exists() else repo
            if not os.access(parent, os.W_OK):
                raise ValueError(f"workspace settings location is not writable: {path}")
            print("OK")
            return 0

        color = (
            project_color(project_name(repo)).hex.lower()
            if args.color.casefold() == "auto"
            else f"#{args.color.strip().removeprefix('#').lower()}"
        )
        if not re.fullmatch(r"#[0-9a-f]{6}", color):
            parser.error("COLOR must be a six-digit hexadecimal color or 'auto'")
        content = (
            json.dumps(updated_settings(settings, color), indent=2, ensure_ascii=False)
            + "\n"
        )
        if args.dry_run:
            print(content, end="")
            return 0
        if path.exists() and not args.yes:
            try:
                confirmation = input(f"Replace {path}? [y/N] ")
            except EOFError:
                confirmation = ""
            if confirmation.strip().lower() not in {"y", "yes"}:
                return 1
        if not path.exists() or path.read_text(encoding="utf-8") != content:
            atomic_write(path, content)
        print(path)
        return 0
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
