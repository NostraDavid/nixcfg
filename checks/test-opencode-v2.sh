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
assert.deepEqual(config.skills, ["~/.codex/skills", "~/.codex/skills/.system", "~/.codex/plugins/cache"]);
for (const [action, resource, effect] of [
    ["shell", "git push *", "allow"],
    ["shell", "git reset --hard *", "ask"],
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
assert.equal(config.model.providerID, "openai");
assert.equal(config.model.model, "gpt-6.1-terra");
assert.ok(!("variant" in config.model), "The v2 root model does not retain a variant");
assert.deepEqual(config.agents.codex.model, {
    providerID: "openai",
    model: "gpt-6.1-terra",
    variant: "medium",
});
assert.equal(config.agents["opencode-worker"].model.providerID, "openai");
assert.deepEqual(config.policies.filter(rule => rule.action === "provider.use"), [
    { action: "provider.use", resource: "*", effect: "deny" },
    { action: "provider.use", resource: provider, effect: "allow" },
    { action: "provider.use", resource: "openai", effect: "allow" },
]);
assert.equal(config.providers.tensorx.package, "aisdk:@ai-sdk/openai-compatible");
assert.equal(config.agents["opencode-worker"].model.model, "gpt-6-luna");
assert.equal(config.agents["opencode-worker"].model.variant, "xhigh");
assert.deepEqual(Object.keys(config.providers.tensorx.models).sort(), [
    "deepseek/deepseek-v4.1-flash-1017", "qwen/qwen3.8-flash-next", "z-ai/glm-5.3-flash",
]);
assert.equal(config.providers.tensorx.settings.baseURL, "https://api.tensorx.ai/v1");
const expectedServers = ["agent-memory", "chrome-devtools", "dbhub", "nixos", "openaiDeveloperDocs", "playwright"];
assert.deepEqual(Object.keys(config.mcp.servers).sort(), expectedServers);
for (const server of Object.values(config.mcp.servers)) assert.equal(server.disabled, false);
assert.equal(config.mcp.servers.openaiDeveloperDocs.url, "https://developers.openai.com/mcp");
assert.ok(!("node_repl" in config.mcp.servers));
assert.deepEqual(config.mcp.servers.dbhub.command, [`${process.env.HOME}/.local/bin/mcp-dbhub`]);
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
