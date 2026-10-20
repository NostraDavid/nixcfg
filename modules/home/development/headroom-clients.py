"""Configure standalone Headroom and retire generated LeanCTX integrations."""

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path


def configure(home: Path) -> None:
    path = home / ".pi/agent/settings.json"
    if path.exists():
        path = path.resolve()
        original = path.read_text()
        document = json.loads(original)
        document["packages"] = [
            p for p in document.get("packages", []) if p != "npm:pi-lean-ctx"
        ]
        updated = json.dumps(document, indent=2) + "\n"
        if updated != original:
            backup = path.with_name(path.name + ".before-headroom")
            if not backup.exists():
                shutil.copy2(path, backup)
            fd, temporary = tempfile.mkstemp(dir=path.parent)
            temporary = Path(temporary)
            try:
                with os.fdopen(fd, "w") as stream:
                    stream.write(updated)
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)

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
