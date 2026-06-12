#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///

from __future__ import annotations

import pathlib
import re
import sys

SCOPE_RE = re.compile(r"^[a-z0-9][a-z0-9._/-]*: .+")
CONVENTIONAL_RE = re.compile(
    r"^(feat|fix|chore|docs|refactor|test|build|ci|perf|style|revert)(\(.+\))?!?: ",
    re.IGNORECASE,
)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_scoped_commit_msg.py <commit-msg-file>", file=sys.stderr)
        return 2

    msg_path = pathlib.Path(sys.argv[1])
    if not msg_path.exists():
        print(f"commit message file not found: {msg_path}", file=sys.stderr)
        return 2

    first_line = ""
    for line in msg_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            first_line = stripped
            break

    if not first_line:
        print("empty commit message", file=sys.stderr)
        return 1

    if CONVENTIONAL_RE.match(first_line):
        print(
            "Conventional Commit prefixes are disabled. Use scoped format: <scope>: <summary>",
            file=sys.stderr,
        )
        return 1

    if not SCOPE_RE.match(first_line):
        print(
            "Commit message must match scoped format: <scope>: <summary>\n"
            "Use a literal ':' between <scope> and <summary>.\n"
            "Examples:\n"
            "  dotfiles: normalize mappings\n"
            "  dev-tools: update bootstrap",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
