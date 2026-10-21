"""Configure stable MCP launchers while retaining unrelated client settings."""

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

import json5
import tomlkit


def merge_codex(document: dict, servers: dict) -> None:
    managed = {
        name: dict(server) for name, server in document.get("mcp_servers", {}).items()
    }
    # Backend registrations now share the stable client name agent-memory.
    for backend_name in ("engram", "engrim"):
        managed.pop(backend_name, None)
    # Headroom replaces the former LeanCTX integration.
    managed.pop("lean-ctx", None)
    for name, server in servers.items():
        current = dict(managed.get(name, {}))
        if name == "node_repl":
            environment = dict(current.get("env", {}))
            for key in (
                "NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS",
                "NODE_REPL_NODE_MODULE_DIRS",
                "NODE_REPL_NODE_PATH",
                "NODE_REPL_TRUSTED_CODE_PATHS",
                "NODE_REPL_TRUSTED_SERVICES",
                "CODEX_HOME",
                "CODEX_CLI_PATH",
                "BROWSER_USE_AVAILABLE_BACKENDS",
                "BROWSER_USE_TINYSKY_ENABLED",
                "BROWSER_USE_CODEX_APP_BUILD_FLAVOR",
                "BROWSER_USE_CODEX_APP_VERSION",
                "NODE_REPL_INSTRUCTIONS_USE_CASE_BROWSER",
                "NODE_REPL_INSTRUCTIONS_USE_CASE_CHROME",
            ):
                environment.pop(key, None)
            if not environment:
                current.pop("env", None)
            else:
                current["env"] = environment
        current.update(server)
        if "command" in server:
            current["args"] = server.get("args", [])
        managed[name] = current
    document["mcp_servers"] = managed


def configure(
    home: Path,
    servers: dict,
    codex_overrides: dict | None = None,
    removed_servers: tuple[str, ...] = (),
) -> None:
    for relative in (".codex/config.toml", ".config/opencode/opencode.jsonc"):
        path = home / relative
        original = path.read_text() if path.exists() else ""
        if path.suffix == ".toml":
            document = tomlkit.loads(original)
            merge_codex(document, servers | (codex_overrides or {}))
            for name in removed_servers:
                document["mcp_servers"].pop(name, None)
            updated = tomlkit.dumps(document)
        else:
            document = json5.loads(original) if original else {}
            managed = document.setdefault("mcp", {}).setdefault("servers", {})
            for name, server in servers.items():
                current = managed.setdefault(name, {})
                current.update(
                    {
                        "type": "local",
                        "command": [server["command"], *server.get("args", [])],
                        "disabled": current.get("disabled", False),
                    }
                )
                if server.get("env"):
                    current["environment"] = server["env"]
                if "startup_timeout_sec" in server:
                    current.setdefault("timeout", {})["startup"] = (
                        server["startup_timeout_sec"] * 1000
                    )
            managed.pop("node_repl", None)
            updated = json.dumps(document, indent=2) + "\n"
        if updated == original:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        backup = path.with_name(path.name + ".before-mcp")
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
    configure(
        Path(sys.argv[1]),
        json.loads(sys.argv[2]),
        json.loads(sys.argv[3]) if len(sys.argv) > 3 else None,
        tuple(json.loads(sys.argv[4])) if len(sys.argv) > 4 else (),
    )
