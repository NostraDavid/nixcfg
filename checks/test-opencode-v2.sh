#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
package=$(nix build "path:$root#opencode-v2" --no-link --print-out-paths)
opencode="$package/bin/opencode"

export XDG_CONFIG_HOME="$tmp/config"
export XDG_DATA_HOME="$tmp/data"
export XDG_STATE_HOME="$tmp/state"
export XDG_CACHE_HOME="$tmp/cache"
export OPENCODE_DISABLE_MODELS_FETCH=1
unset OPENCODE_DB OPENCODE_CONFIG OPENCODE_CONFIG_DIR OPENCODE_CONFIG_CONTENT NIXPKGS_OPENCODE_DISABLE_LEGACY_DB_WORKAROUND
mkdir -p "$XDG_CONFIG_HOME/opencode" "$XDG_DATA_HOME/opencode"
cd "$tmp"
"$opencode" --version
# Keep every probe private rather than registering a background service.
"$opencode" service set disabled true
cp "$root/dotfiles/opencode-2.0.32/.config/opencode/opencode.jsonc" \
    "$XDG_CONFIG_HOME/opencode/opencode.jsonc"
"$opencode" debug config >"$tmp/personal.json"
node --input-type=module - "$tmp/personal.json" <<'JS'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const config = JSON.parse(readFileSync(process.argv[2], "utf8"))[0].info;
const source = JSON.parse(readFileSync(`${process.env.XDG_CONFIG_HOME}/opencode/opencode.jsonc`, "utf8"));
for (const key of ["agent", "autoupdate", "permission", "provider", "snapshot", "enabled_providers", "disabled_providers", "plugin"]) {
    assert.ok(!(key in source), `Deprecated v1 configuration key: ${key}`);
}
assert.ok(source.mcp.servers, "Use native v2 mcp.servers");
for (const server of Object.values(source.mcp.servers)) {
    assert.ok(!("enabled" in server), "Use native v2 MCP disabled");
    assert.notEqual(typeof server.timeout, "number", "Use native v2 MCP timeout fields");
}
for (const agent of Object.values(source.agents)) {
    assert.ok(!("prompt" in agent) && !("permission" in agent), "Use native v2 agent fields");
}
assert.equal(config.update, "disable");
assert.equal(config.default_agent, "codex");
assert.equal(config.experimental.subagent_depth, 1);
assert.deepEqual(config.plugins, ["opencode-queue@2.0.2"]);
for (const [action, resource, effect] of [
    ["shell", "git push *", "deny"],
    ["shell", "git reset --hard *", "deny"],
    ["shell", "git commit *", "ask"],
    ["external_directory", "*", "ask"],
]) {
    assert.ok(config.permissions.some(rule => rule.action === action && rule.resource === resource && rule.effect === effect));
}
assert.deepEqual(config.agents.codex.permissions, [
    { action: "subagent", resource: "*", effect: "deny" },
    { action: "subagent", resource: "opencode-worker", effect: "allow" },
]);
const provider = "tensorx";
assert.deepEqual(Object.keys(config.providers), [provider]);
assert.equal(config.model.providerID, provider);
for (const agent of Object.values(config.agents)) assert.equal(agent.model.providerID, provider);
assert.deepEqual(config.policies.filter(rule => rule.action === "provider.use"), [
    { action: "provider.use", resource: "*", effect: "deny" },
    { action: "provider.use", resource: provider, effect: "allow" },
]);
assert.equal(config.providers.tensorx.package, "aisdk:@ai-sdk/openai-compatible");
assert.equal(config.model.model, "z-ai/glm-5.3-flash");
assert.equal(config.providers.tensorx.settings.baseURL, "https://api.tensorx.ai/v1");
const expectedServers = ["agent-memory", "chrome-devtools", "dbhub", "headroom", "nixos", "openaiDeveloperDocs", "playwright", "qartez"];
assert.deepEqual(Object.keys(config.mcp.servers).sort(), expectedServers);
for (const server of Object.values(config.mcp.servers)) assert.equal(server.disabled, false);
assert.equal(config.mcp.servers.openaiDeveloperDocs.url, "https://developers.openai.com/mcp");
assert.ok(!("node_repl" in config.mcp.servers));
assert.ok(config.mcp.servers.dbhub.command[0].endsWith("/.local/bin/dbhub"));
assert.deepEqual(config.mcp.servers.dbhub.command.slice(1, 4), ["--transport", "stdio", "--config"]);
assert.ok(config.mcp.servers.dbhub.command[4].endsWith("/.config/dbhub/local.toml"));
JS

# Path inspection must preserve the old nixpkgs database selection without opening it.
rm -f "$XDG_DATA_HOME/opencode/"*.db*
touch "$XDG_DATA_HOME/opencode/opencode-stable.db"
test "$("$opencode" debug paths db)" = "$XDG_DATA_HOME/opencode/opencode-stable.db"
touch "$XDG_DATA_HOME/opencode/opencode.db"
test "$("$opencode" debug paths db)" = "$XDG_DATA_HOME/opencode/opencode.db"
test "$(OPENCODE_DB=custom.db "$opencode" debug paths db)" = "$XDG_DATA_HOME/opencode/custom.db"
test ! -s "$XDG_DATA_HOME/opencode/opencode-stable.db"
rm "$XDG_DATA_HOME/opencode/"*.db

# Exercise the actual v2 service without credentials, model calls or MCP processes.
printf '{"update":"disable"}\n' >"$XDG_CONFIG_HOME/opencode/opencode.jsonc"
timeout 30 "$opencode" api --standalone server.info >"$tmp/server.json"
node --input-type=module - "$tmp/server.json" <<'JS'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
assert.match(JSON.parse(readFileSync(process.argv[2], "utf8")).version, /^2\./);
JS
echo 'OpenCode v2 config, database paths and private API checks passed.'
