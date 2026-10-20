#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
nix eval --impure --json --file "$root/checks/loki-mcp.nix" checks
nix eval --impure --json --file "$root/checks/loki-mcp.nix" servers >"$tmp/servers.json"
python=$(nix build --impure --file "$root/checks/loki-mcp.nix" python --no-link --print-out-paths)
"$python/bin/python" - "$root" "$tmp" <<'PY'
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tomllib

root, tmp = map(Path, sys.argv[1:])
configure = runpy.run_path(root / "modules/home/loki-mcp-clients.py")["configure"]
servers = json.loads((tmp / "servers.json").read_text())
servers["node_repl"]["startup_timeout_sec"] = 120
home = tmp / "home"
codex = home / ".codex/config.toml"
opencode = home / ".config/opencode/opencode.jsonc"
codex.parent.mkdir(parents=True)
opencode.parent.mkdir(parents=True)
codex.write_text('model = "existing-model"\n[mcp_servers.custom]\ncommand = "custom-server"\n')
original = '{\n// Keep work authentication and providers\n"providers":{"work":{"settings":{"apiKey":"{env:WORK_KEY}"}}},"mcp":{"servers":{"custom":{"type":"remote","url":"https://example.invalid"}}}}'
source = tmp / "user-config.jsonc"
source.write_text(original)
opencode.symlink_to(source)
configure(home, servers)
assert source.read_text() == original
assert not opencode.is_symlink()
assert tomllib.loads(codex.read_text())["model"] == "existing-model"
assert set(tomllib.loads(codex.read_text())["mcp_servers"]) == {*servers, "custom"}
config = json.loads(opencode.read_text())
assert config["providers"]["work"]["settings"]["apiKey"] == "{env:WORK_KEY}"
assert set(config["mcp"]["servers"]) == {*servers, "custom"}
assert config["mcp"]["servers"]["node_repl"]["timeout"]["startup"] == 120000
(tmp / "native.jsonc").write_text(json.dumps({"update": "disable", "mcp": config["mcp"]}))
assert opencode.with_name(opencode.name + ".before-loki-mcp").read_text() == original
assert opencode.stat().st_mode & 0o777 == 0o600
first = (codex.read_bytes(), opencode.read_bytes())
configure(home, servers)
assert first == (codex.read_bytes(), opencode.read_bytes())
opencode.write_text('{broken')
try:
    configure(home, servers)
except ValueError:
    pass
else:
    raise AssertionError("Malformed user configuration must be rejected")
assert opencode.read_text() == '{broken'

# Exercise the real launcher against a native-app fixture, including spaces.
launcher = tmp / "node-repl.sh"
launcher.write_text((root / "modules/home/loki-node-repl.sh").read_text().replace("/Applications/", str(tmp / "Applications") + "/"))
environment = dict(os.environ, HOME=str(home))
missing = subprocess.run(["bash", launcher], env=environment, capture_output=True, text=True)
assert missing.returncode == 1 and "requires Codex.app" in missing.stderr
runtime = tmp / "Applications/Codex.app/Contents/Resources/cua_node"
(runtime / "bin").mkdir(parents=True)
for name in ("node", "node_repl"):
    script = runtime / "bin" / name
    script.write_text('#!/bin/sh\nprintf "%s\\n" "$NODE_REPL_NODE_PATH" "$NODE_REPL_NODE_MODULE_DIRS" "$@"\n')
    script.chmod(0o755)
result = subprocess.run(["bash", launcher, "argument with spaces"], env=environment, capture_output=True, text=True, check=True)
assert result.stdout.splitlines() == [str(runtime / "bin/node"), str(runtime / "lib/node_modules"), "argument with spaces"]
print("Loki MCP client migration, provider preservation and Node REPL launcher checks passed.")
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
assert.equal(Object.keys(config.mcp.servers).length, 9);
assert.equal(config.mcp.servers.node_repl.timeout.startup, 120000);
assert.ok(config.mcp.servers.dbhub.command.includes("/Users/david/.config/dbhub/local.toml"));
console.log("Generated Loki MCP connections normalize through OpenCode v2.");
JS
