#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# ///

from __future__ import annotations

import argparse
import hashlib
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Color:
    red: int
    green: int
    blue: int

    @property
    def hex(self) -> str:
        return f"#{self.red:02X}{self.green:02X}{self.blue:02X}"

    @property
    def luminance(self) -> int:
        return (299 * self.red + 587 * self.green + 114 * self.blue) // 1000


def project_color(name: str) -> Color:
    digest = hashlib.sha1(name.encode()).hexdigest()
    color = Color(
        red=int(digest[0:2], 16),
        green=int(digest[2:4], 16),
        blue=int(digest[4:6], 16),
    )

    if color.luminance < 60:
        return Color(
            red=(color.red + 0xAA) // 2,
            green=(color.green + 0xAA) // 2,
            blue=(color.blue + 0xAA) // 2,
        )

    if color.luminance > 200:
        return Color(
            red=(color.red + 0x55) // 2,
            green=(color.green + 0x55) // 2,
            blue=(color.blue + 0x55) // 2,
        )

    return color


def print_preview(name: str, color: Color) -> None:
    if color.luminance > 128:
        foreground = "0;0;0"
    else:
        foreground = "255;255;255"

    print(
        f"\033[48;2;{color.red};{color.green};{color.blue}m"
        f"\033[38;2;{foreground}m {name} ({color.hex}) \033[0m"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print a deterministic readable hex color for a project name."
    )
    parser.add_argument(
        "name",
        nargs="?",
        default=Path.cwd().name,
        help="Project name. Defaults to the current directory name.",
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Print a terminal color preview instead of only the hex value.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    color = project_color(args.name)
    if args.preview:
        print_preview(args.name, color)
    else:
        print(color.hex)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
