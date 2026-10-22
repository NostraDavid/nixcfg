"""Retire legacy LeanCTX resources without rewriting client dotfiles."""

import shutil
import sys
import tempfile
from pathlib import Path


def configure(home: Path) -> None:
    # Move generated integrations out of client discovery; retain user data.
    for relative in [
        ".codex/skills/lean-ctx",
        ".claude/skills/lean-ctx",
        ".copilot/skills/lean-ctx",
        ".config/opencode/skills/lean-ctx",
        ".pi/agent/extensions/pi-lean-ctx",
        ".config/lean-ctx",
    ]:
        path = home / relative
        if not path.exists() and not path.is_symlink():
            continue
        backup = home / ".local/state/nixcfg/removed-lean-ctx" / relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        if backup.exists() or backup.is_symlink():
            backup = (
                Path(tempfile.mkdtemp(prefix=backup.name + "-", dir=backup.parent))
                / path.name
            )
        shutil.move(str(path), str(backup))


if __name__ == "__main__":
    configure(Path(sys.argv[1]))
