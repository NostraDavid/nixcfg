#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
nix eval --impure --json --file "$root/checks/loki-mcp.nix" checks
nix eval --impure --json --file "$root/checks/loki-mcp.nix" servers >"$tmp/servers.json"
nix eval --impure --json --file "$root/checks/loki-mcp.nix" profileServers >"$tmp/profile-servers.json"
python=$(nix build --impure --file "$root/checks/loki-mcp.nix" python --no-link --print-out-paths)
wodan_scripts=$(nix build --impure --file "$root/checks/loki-mcp.nix" wodanScripts --no-link --print-out-paths)
wodan_launchers=$(nix build --impure --file "$root/checks/loki-mcp.nix" wodanLaunchers --no-link --print-out-paths)
mkdir -p "$tmp/wodan/.codex"
cp "$root/dotfiles/codex-0.140.0/.codex/config.toml" "$tmp/wodan/.codex/config.toml"
cat >>"$tmp/wodan/.codex/config.toml" <<'EOF'

[mcp_servers.node_repl.env]
CUSTOM_KEEP = "fixture-value"
NODE_REPL_NODE_PATH = "/nix/store/old-runtime/node"
EOF
for pass in first second; do
    for writer in headroomClients mcpClients; do
        sed "s#/home/david#${tmp}/wodan#g" "$wodan_scripts/$writer" | HOME="$tmp/wodan" DRY_RUN_CMD="" bash
    done
    if [[ "$pass" == first ]]; then
        cp "$tmp/wodan/.codex/config.toml" "$tmp/wodan-first.toml"
    else
        cmp "$tmp/wodan-first.toml" "$tmp/wodan/.codex/config.toml"
    fi
done
"$python/bin/python" - "$tmp/wodan/.codex/config.toml" <<'PY'
from pathlib import Path
import sys
import tomllib

servers = tomllib.loads(Path(sys.argv[1]).read_text())["mcp_servers"]
assert len(servers) == 10
assert "/nix/store/" not in str(servers)
assert servers["node_repl"]["env"] == {"CUSTOM_KEEP": "fixture-value"}
assert servers["node_repl"]["command"].endswith("/.local/bin/codex-mcp-node-repl")
assert not servers["cua_repl"]["enabled"]
PY
# Separate launchers retain the browser bridge only for Codex.
rg -q 'export NODE_REPL_TRUSTED_SERVICES=' "$wodan_launchers/codex-mcp-node-repl"
rg -q '/.codex/plugins/cache/openai-bundled/browser/' "$wodan_launchers/codex-mcp-node-repl"
if rg -q 'TRUSTED_SERVICES|BROWSER_USE_' "$wodan_launchers/mcp-node-repl"; then
    echo 'OpenCode Node REPL must remain independent of the Codex browser bridge' >&2
    exit 1
fi
"$python/bin/python" - "$root" "$tmp" <<'PY'
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tomllib

root, tmp = map(Path, sys.argv[1:])
configure = runpy.run_path(root / "features/mcp/mcp-clients.py")["configure"]
servers = json.loads((tmp / "servers.json").read_text())
# OpenCode and Pi omit Node REPL on every host.
profiles = json.loads((tmp / "profile-servers.json").read_text())
assert set(profiles) == {"wodan", "frigg", "donar", "bragi", "loki", "mimir2"}
for name, entries in profiles.items():
    assert set(entries) == set(servers), name
    fixture_home = tmp / "profiles" / name
    configure(fixture_home, entries)
    registered = tomllib.loads((fixture_home / ".codex/config.toml").read_text())["mcp_servers"]
    assert all(registered[key]["command"] == value["command"] for key, value in entries.items()), name
    assert "/nix/store/" not in str(registered), name

home = tmp / "home"
codex = home / ".codex/config.toml"
opencode = home / ".config/opencode/opencode.jsonc"
codex.parent.mkdir(parents=True)
opencode.parent.mkdir(parents=True)
codex.write_text('model = "existing-model"\n[mcp_servers.custom]\ncommand = "custom-server"\n')
with codex.open("a") as stream:
    stream.write('[mcp_servers.engram]\ncommand = "old-name"\n[mcp_servers.engrim]\ncommand = "old-name"\n[mcp_servers.lean-ctx]\ncommand = "old-name"\n')
databases = [home / f".local/share/{backend}/fixture.db" for backend in ("engram", "engrim")]
for path in databases:
    path.parent.mkdir(parents=True)
    path.write_text("preserve-existing-database")
original = '{\n// Keep work authentication and providers\n"providers":{"work":{"settings":{"apiKey":"{env:WORK_KEY}"}}},"mcp":{"servers":{"custom":{"type":"remote","url":"https://example.invalid"}}}}'
source = tmp / "user-config.jsonc"
source.write_text(original)
opencode.symlink_to(source)
configure(home, servers)
assert source.read_text() == original
assert not opencode.is_symlink()
assert tomllib.loads(codex.read_text())["model"] == "existing-model"
assert set(tomllib.loads(codex.read_text())["mcp_servers"]) == {*servers, "custom"}
assert all(path.read_text() == "preserve-existing-database" for path in databases)
config = json.loads(opencode.read_text())
assert config["providers"]["work"]["settings"]["apiKey"] == "{env:WORK_KEY}"
assert set(config["mcp"]["servers"]) == {*servers, "custom"}
assert "node_repl" not in config["mcp"]["servers"]
(tmp / "native.jsonc").write_text(json.dumps({"update": "disable", "mcp": config["mcp"]}))
assert opencode.with_name(opencode.name + ".before-mcp").read_text() == original
assert opencode.stat().st_mode & 0o777 == 0o600
first = (codex.read_bytes(), opencode.read_bytes())
configure(home, servers)
assert first == (codex.read_bytes(), opencode.read_bytes())

# Upgrading the backing executable must not rewrite either client configuration.
link = home / ".local/bin/fixture-mcp"
link.parent.mkdir(parents=True)
fixture = {"fixture": {"command": str(link)}}
configure(home, fixture)
before = [(path.read_bytes(), path.stat().st_mtime_ns) for path in (codex, opencode)]
for version in ("old", "new"):
    executable = tmp / version
    executable.write_text(f"#!/bin/sh\nprintf '%s\\n' {version}\n")
    executable.chmod(0o755)
    link.unlink(missing_ok=True)
    link.symlink_to(executable)
    configure(home, fixture)
    assert before == [(path.read_bytes(), path.stat().st_mtime_ns) for path in (codex, opencode)]
    assert subprocess.check_output([link], text=True).strip() == version

opencode.write_text('{broken')
try:
    configure(home, servers)
except ValueError:
    pass
else:
    raise AssertionError("Malformed user configuration must be rejected")
assert opencode.read_text() == '{broken'

# Native dotfiles must work with a different username, a space in HOME and no PATH lookup.
portable_home = tmp / "other user"
bin_dir = portable_home / ".local/bin"
bin_dir.mkdir(parents=True)
expected = {"agent-memory": ["mcp"], "headroom": ["mcp", "serve", "--transport", "stdio"], "qartez": [], "node_repl": []}
commands = {"agent-memory": "agent-memory", "headroom": "headroom", "qartez": "qartez", "node_repl": "mcp-node-repl"}
for command in commands.values():
    executable = bin_dir / command
    executable.write_text('#!/bin/sh\nfor arg do printf "%s\\n" "$arg"; done\n')
    executable.chmod(0o755)
documents = [
    ("dotfiles/copilot-1.0.65/.copilot/mcp-config.json", "mcpServers"),
    ("dotfiles/mcp/.config/mcp/mcp.json", "mcpServers"),
    ("dotfiles/vscode-1.106.2/.config/Code/User/mcp.json", "servers"),
]
for relative, key in documents:
    entries = json.loads((root / relative).read_text())[key]
    for name, server in entries.items():
        result = subprocess.check_output([server["command"], *server.get("args", [])], env=dict(os.environ, HOME=str(portable_home), PATH="/nonexistent"), text=True)
        assert result.splitlines() == expected[name], (relative, name, result)
for name, server in tomllib.loads((root / "dotfiles/codex-0.140.0/.codex/config.toml").read_text())["mcp_servers"].items():
    if server.get("enabled", True) and "command" in server:
        result = subprocess.check_output([server["command"], *server.get("args", [])], env=dict(os.environ, HOME=str(portable_home), PATH="/nonexistent"), text=True)
        assert result.splitlines() == expected[name], name

# OpenCode removes Node REPL while Codex retains its client-specific runtime.
opencode.write_text("{}")
configure(home, servers, {"node_repl": {"command": "codex-node-repl"}})
assert tomllib.loads(codex.read_text())["mcp_servers"]["node_repl"]["command"] == "codex-node-repl"
config = json.loads(opencode.read_text())
config["mcp"]["servers"]["node_repl"] = {"command": ["old-node-repl"]}
opencode.write_text(json.dumps(config))
configure(home, servers, {"node_repl": {"command": "codex-node-repl"}})
assert "node_repl" not in json.loads(opencode.read_text())["mcp"]["servers"]
assert "node_repl" in tomllib.loads(codex.read_text())["mcp_servers"]

# Activation also removes the Codex registration on Loki without touching others.
for path, content in (
    (codex, '[mcp_servers.node_repl]\ncommand = "old-node-repl"\n[mcp_servers.custom]\ncommand = "keep-me"\n'),
    (opencode, json.dumps({"mcp": {"servers": {"node_repl": {"command": ["old-node-repl"]}, "custom": {"type": "remote", "url": "https://example.invalid"}}}})),
):
    path.write_text(content)
configure(home, servers, removed_servers=("node_repl",))
assert "node_repl" not in tomllib.loads(codex.read_text())["mcp_servers"]
assert "node_repl" not in json.loads(opencode.read_text())["mcp"]["servers"]
assert tomllib.loads(codex.read_text())["mcp_servers"]["custom"]["command"] == "keep-me"
assert json.loads(opencode.read_text())["mcp"]["servers"]["custom"]["url"] == "https://example.invalid"
first = (codex.read_bytes(), opencode.read_bytes())
configure(home, servers, removed_servers=("node_repl",))
assert first == (codex.read_bytes(), opencode.read_bytes())
print("Loki MCP client migration and Node REPL removal checks passed.")
PY

# Normalize the generated MCP entries through the real OpenCode v2 parser.
package=$(nix build "path:$root#opencode-v2" --no-link --print-out-paths)
export XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache"
export OPENCODE_CONFIG="$tmp/native.jsonc" OPENCODE_DISABLE_MODELS_FETCH=1
unset OPENCODE_CONFIG_DIR OPENCODE_CONFIG_CONTENT OPENCODE_DB
cd "$tmp"
"$package/bin/opencode" service set disabled true
"$package/bin/opencode" debug config >"$tmp/native.json"
node --input-type=module - "$tmp/native.json" <<'JS'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const output = JSON.parse(readFileSync(process.argv[2], "utf8"));
const config = output.find(entry => entry.info?.mcp)?.info;
assert.ok(config, JSON.stringify(output));
assert.equal(Object.keys(config.mcp.servers).length, 8);
assert.ok(!("node_repl" in config.mcp.servers));
assert.ok(config.mcp.servers.dbhub.command.includes("/Users/david/.config/dbhub/local.toml"));
console.log("Generated Loki MCP connections normalize through OpenCode v2.");
JS
