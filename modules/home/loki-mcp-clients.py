"""Merge Loki's MCP servers while retaining each client's provider settings."""

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

import json5
import tomlkit


def configure(home: Path, servers: dict) -> None:
    for relative in (".codex/config.toml", ".config/opencode/opencode.jsonc"):
        path = home / relative
        original = path.read_text() if path.exists() else ""
        if path.suffix == ".toml":
            document = tomlkit.loads(original)
            document.setdefault("mcp_servers", {}).update(servers)
            updated = tomlkit.dumps(document)
        else:
            document = json5.loads(original) if original else {}
            managed = document.setdefault("mcp", {}).setdefault("servers", {})
            for name, server in servers.items():
                managed[name] = {
                    "type": "local",
                    "command": [server["command"], *server.get("args", [])],
                    "disabled": False,
                }
                if server.get("env"):
                    managed[name]["environment"] = server["env"]
                if "startup_timeout_sec" in server:
                    managed[name]["timeout"] = {
                        "startup": server["startup_timeout_sec"] * 1000
                    }
            updated = json.dumps(document, indent=2) + "\n"
        if updated == original:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        backup = path.with_name(path.name + ".before-loki-mcp")
        if path.exists() and not backup.exists():
            shutil.copy2(path, backup)
        fd, temporary = tempfile.mkstemp(dir=path.parent)
        temporary = Path(temporary)
        try:
            with os.fdopen(fd, "w") as stream:
                stream.write(updated)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    configure(Path(sys.argv[1]), json.loads(sys.argv[2]))
