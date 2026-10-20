# MCP on Loki

Loki configures these servers for Codex, OpenCode and Pi:

- Node REPL
- Agent-memory, using Engrim
- Headroom
- DBHub
- Chrome DevTools
- Playwright
- NixOS
- Qartez

Pi also retains its existing Exa and OpenAI Developer Docs connections.

## Dependencies

Nix installs the server packages. Headroom uses the pinned macOS ARM64 wheels
from [Headroom 0.41.0](https://pypi.org/project/headroom-ai/0.41.0/).

Node REPL uses the native `cua_node` runtime from an installed Codex.app or
ChatGPT.app in `/Applications` or `~/Applications`. The launcher checks for the
runtime and reports a missing installation. It does not use Wodan's Linux
executables. This provides the JavaScript MCP server; browser-plugin setup
inside the desktop app remains separate.

The browser servers require an installed Google Chrome. Both start headless,
isolated browser sessions. Chrome DevTools usage statistics and CrUX requests
are disabled.

DBHub uses `~/.config/dbhub/local.toml` and a separate SQLite sandbox at
`~/.local/share/dbhub/local.sqlite`. It does not connect to Wodan's database or
other databases. The sandbox directory has mode 700.

## Activation

Apply the existing nix-darwin configuration on Loki. The shared `mkLoki`
constructor includes this setup, including when the work repository supplies a
different username or home directory.

Activation merges the eight servers into `~/.codex/config.toml` and the native
v2 `mcp.servers` section in `~/.config/opencode/opencode.jsonc`. Existing model,
provider and unrelated MCP settings are retained. First-change backups have the
suffix `.before-loki-mcp`. OpenCode JSONC comments are accepted; the updated
file is written as formatted JSON. A symlink is replaced locally, preserving its
original target. Pi receives its connections through its native Nix module.

Restart Codex and Pi, and run `opencode service restart` before checking:

```bash
codex mcp list
pi mcp list --json
opencode mcp list
```

## Checks

```bash
bash checks/test-loki-mcp.sh
nix eval --impure --json --file checks/tooling.nix
```

The tests evaluate Loki and a custom work username, exercise configuration
preservation, backups, idempotence and malformed input, and run the Node REPL
launcher against an app fixture. Real macOS server connections still need a
check on Loki after activation.
