const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { runInNewContext } = require("node:vm");

const source = readFileSync(
  `${process.argv[2]}/node_modules/@agentclientprotocol/codex-acp/dist/index.js`,
  "utf8",
);
const start = source.indexOf("var AgentMode = class ");
assert.notEqual(start, -1);
const end = source.indexOf("\n};", start);
assert.notEqual(end, -1);
const modes = `${source.slice(start, end + 3)}; AgentMode`;

for (
  const [requested, runner, expected] of [
    [undefined, undefined, false],
    ["true", "enabled", true],
    ["false", "enabled", false],
    ["true", "disabled", false],
  ]
) {
  const AgentMode = runInNewContext(modes, {
    process: {
      env: {
        PAPERCLIP_CODEX_ACP_NETWORK_ACCESS: requested,
        PAPERCLIP_RUNNER_NETWORK_ACCESS: runner,
      },
    },
  });
  for (const mode of [AgentMode.ReadOnly, AgentMode.Agent]) {
    assert.equal(mode.sandboxPolicy.type, "workspaceWrite");
    assert.equal(mode.sandboxPolicy.networkAccess, expected);
  }
}
console.log("PASS: Codex ACP respects Paperclip network access and runner denial");
