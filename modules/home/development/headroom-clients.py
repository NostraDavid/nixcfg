"""Configure standalone Headroom and retire generated LeanCTX integrations."""

import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

import tomlkit


def configure(home, command):
    server = {"command": command, "args": ["mcp", "serve", "--transport", "stdio"]}
    for relative, section, loads, dumps in [
        (".codex/config.toml", "mcp_servers", tomlkit.loads, tomlkit.dumps),
        (
            ".claude.json",
            "mcpServers",
            json.loads,
            lambda value: json.dumps(value, indent=2) + "\n",
        ),
        (
            ".config/opencode/opencode.json",
            "mcp",
            json.loads,
            lambda value: json.dumps(value, indent=2) + "\n",
        ),
        (
            ".pi/agent/settings.json",
            None,
            json.loads,
            lambda value: json.dumps(value, indent=2) + "\n",
        ),
    ]:
        path = home / relative
        if not path.exists() and section in (None, "mcp"):
            continue
        path = path.resolve()
        original = path.read_text() if path.exists() else ""
        document = loads(original) if original else {}
        if section is None:
            document["packages"] = [
                p for p in document.get("packages", []) if p != "npm:pi-lean-ctx"
            ]
        else:
            servers = document.setdefault(section, {})
            servers.pop("lean-ctx", None)
            servers["headroom"] = (
                {
                    "type": "local",
                    "command": [command, *server["args"]],
                    "enabled": True,
                }
                if section == "mcp"
                else dict(server)
            )
        updated = dumps(document)
        if updated == original:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        backup = path.with_name(path.name + ".before-headroom")
        if path.exists() and not backup.exists():
            shutil.copy2(path, backup)
        fd, temporary = tempfile.mkstemp(dir=path.parent)
        try:
            with os.fdopen(fd, "w") as stream:
                stream.write(updated)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

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
    configure(Path(sys.argv[1]), sys.argv[2])
