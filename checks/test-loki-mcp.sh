#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
nix eval --impure --json --file "$root/checks/loki-mcp.nix" checks
nix eval --impure --json --file "$root/checks/loki-mcp.nix" servers >"$tmp/servers.json"
nix eval --impure --json --file "$root/checks/loki-mcp.nix" fixtureServers >"$tmp/fixture-servers.json"
python=$(nix build --impure --file "$root/checks/loki-mcp.nix" python --no-link --print-out-paths)
wrappers=$(nix build --impure --file "$root/checks/loki-mcp.nix" clientWrappers --no-link --print-out-paths)
real_codex=$(nix build --impure --file "$root/checks/loki-mcp.nix" realCodex --no-link --print-out-paths)
real_opencode="$(nix build --impure --file "$root/checks/loki-mcp.nix" realOpenCode --no-link --print-out-paths)/bin/opencode"
pi_backup=$(nix build --impure --file "$root/checks/loki-mcp.nix" piBackup --no-link --print-out-paths)
"$python/bin/python" - "$root" "$tmp" "$wrappers" "$real_codex" "$real_opencode" "$pi_backup" <<'PYTHON'
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tomllib

root, tmp, wrappers, real_codex, real_opencode, pi_backup = map(Path, sys.argv[1:])
servers = json.loads((tmp / "servers.json").read_text())
fixture_servers = json.loads((tmp / "fixture-servers.json").read_text())
home = tmp / "user home"
codex = home / ".codex/config.toml"
opencode = home / ".config/opencode/opencode.jsonc"
settings = home / ".pi/agent/settings.json"
codex_source = "".join(
    f'[mcp_servers.{name}]\ncommand="/bin/sh"\nargs='
    + json.dumps(["-c", f'exec "$HOME/.local/bin/mcp-{name}"'])
    + "\n"
    for name in servers
)
codex_source += (
    '[mcp_servers.node_repl]\ncommand="/bin/sh"\nargs='
    + json.dumps(["-c", 'exec "$HOME/.local/bin/mcp-node-repl"'])
    + '\n[mcp_servers.custom]\ncommand="custom-server"\n'
)
for path, text in (
    (codex, codex_source),
    (
        opencode,
        json.dumps(
            {
                "update": "disable",
                "mcp": {
                    "servers": {
                        **{
                            name: {
                                "type": "local",
                                "command": ["{env:HOME}/.local/bin/mcp-" + name],
                            }
                            for name in servers
                        },
                        "custom": {"type": "remote", "url": "https://example.invalid"},
                    }
                },
            }
        ),
    ),
    (settings, '{"packages":["npm:pi-lean-ctx"]}'),
):
    path.parent.mkdir(parents=True, exist_ok=True)
    source = tmp / (path.parent.name + "-source" + path.suffix)
    source.write_text(text)
    path.symlink_to(source)
before = {
    p: (p.read_bytes(), p.resolve().stat().st_mtime_ns)
    for p in (codex, opencode, settings)
}
capture = tmp / "capture.json"
env = dict(
    os.environ, HOME=str(home), CODEX_HOME=str(codex.parent), MCP_CAPTURE=str(capture)
)
for platform in ("linux", "macos"):
    subprocess.run(
        [wrappers / (platform + "-codex"), "mcp", "list"], env=env, check=True
    )
    result = json.loads(capture.read_text())
    assert result["args"][-2:] == ["mcp", "list"]
    assert result["path"].split(os.pathsep)[0] == str(home / ".local/bin")
    if platform == "macos":
        assert result["args"][:2] == ["--config", "mcp_servers.node_repl.enabled=false"]
    else:
        assert result["args"] == ["mcp", "list"]
    custom = '{"model":"work/model"}'
    subprocess.run(
        [wrappers / (platform + "-opencode"), "debug", "config"],
        env=dict(env, OPENCODE_CONFIG_CONTENT=custom),
        check=True,
    )
    result = json.loads(capture.read_text())
    assert result["args"] == ["debug", "config"]
    assert result["config"] == custom
    for name, server in fixture_servers[platform].items():
        subprocess.run(
            [wrappers / (platform + "-mcp-" + name), "extra argument"],
            env=env,
            check=True,
        )
        result = json.loads(capture.read_text())
        assert result["args"] == [*server.get("args", []), "extra argument"], (
            platform,
            name,
            result,
        )


# Home Manager backs up old generated Pi files before linking the dotfiles.
def backup_extension(child_env):
    return subprocess.check_output(
        [
            "bash",
            "-c",
            '. "$1"; printf "%s" "${HOME_MANAGER_BACKUP_EXT-}"',
            "backup",
            str(pi_backup),
        ],
        env=child_env,
        text=True,
    )


backup_env = dict(env, HOME_MANAGER_BACKUP_EXT="", HOME_MANAGER_BACKUP_COMMAND="")
assert backup_extension(backup_env) == ""
legacy_home = tmp / "legacy home"
legacy = legacy_home / ".pi/agent/settings.json"
legacy.parent.mkdir(parents=True)
legacy.write_text("preserve this file")
backup_env["HOME"] = str(legacy_home)
assert backup_extension(backup_env) == "before-direct-dotfiles"
assert legacy.read_text() == "preserve this file"
assert (
    backup_extension(dict(backup_env, HOME_MANAGER_BACKUP_EXT="chosen-by-user"))
    == "chosen-by-user"
)

runpy.run_path(root / "features/mcp/headroom-clients.py")["configure"](home)
# Native JSON clients use portable shell launchers without PATH lookup.
bin_dir = home / ".local/bin"
bin_dir.mkdir(parents=True)
commands = {name: "mcp-" + name for name in servers}
expected = dict.fromkeys(servers, [])
for name in commands.values():
    executable = bin_dir / name
    executable.write_text('#!/bin/sh\nfor arg do printf "%s\\n" "$arg"; done\n')
    executable.chmod(0o755)
for relative, key in (
    ("dotfiles/copilot-1.0.65/.copilot/mcp-config.json", "mcpServers"),
    ("dotfiles/mcp/.config/mcp/mcp.json", "mcpServers"),
    ("dotfiles/vscode-1.106.2/.config/Code/User/mcp.json", "servers"),
    ("dotfiles/pi-1.2.0/.pi/agent/mcp.json", "mcpServers"),
):
    for name, server in json.loads((root / relative).read_text())[key].items():
        if "command" not in server or not server.get("enabled", True):
            continue
        result = subprocess.check_output(
            [server["command"], *server.get("args", [])],
            env=dict(env, PATH="/nonexistent"),
            text=True,
        )
        assert result.splitlines() == expected[name], (relative, name, result)

# Check linked configuration through the real Codex parser without starting servers.
result = subprocess.run(
    [real_codex, "mcp", "list", "--json"],
    env=env,
    capture_output=True,
    text=True,
    check=True,
    timeout=30,
)
entries = {entry["name"]: entry for entry in json.loads(result.stdout)}
assert {*servers, "custom"} <= entries.keys()
assert entries["node_repl"]["transport"]["command"] == "/bin/sh"

# Check linked configuration through the real OpenCode parser.
child_env = dict(
    env,
    XDG_CONFIG_HOME=str(home / ".config"),
    XDG_DATA_HOME=str(tmp / "data"),
    XDG_STATE_HOME=str(tmp / "state"),
    XDG_CACHE_HOME=str(tmp / "cache"),
    OPENCODE_CONFIG=str(opencode),
    OPENCODE_DISABLE_MODELS_FETCH="1",
)
for name in ("OPENCODE_CONFIG_CONTENT", "OPENCODE_CONFIG_DIR", "OPENCODE_DB"):
    child_env.pop(name, None)
subprocess.run(
    [real_opencode, "service", "set", "disabled", "true"],
    env=child_env,
    check=True,
    cwd=tmp,
    timeout=30,
)
result = subprocess.run(
    [real_opencode, "debug", "config"],
    env=child_env,
    capture_output=True,
    text=True,
    check=True,
    cwd=tmp,
    timeout=30,
)
config = next(
    entry["info"]
    for entry in json.loads(result.stdout)
    if entry.get("info", {}).get("mcp")
)
assert set(config["mcp"]["servers"]) == {*servers, "custom"}, config["mcp"]["servers"]
assert config["mcp"]["servers"]["dbhub"]["command"] == [
    str(home / ".local/bin/mcp-dbhub")
]
for path, original in before.items():
    assert path.is_symlink(), path
    assert (path.read_bytes(), path.resolve().stat().st_mtime_ns) == original, path
print("MCP launchers preserve linked configs and native client parsing.")
PYTHON
