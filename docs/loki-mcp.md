# Stable MCP commands on all machines

The shared `modules/home/mcp.nix` module configures these servers for Codex,
OpenCode and Pi on Wodan, Donar, Frigg, Bragi, Mimir2 and Loki:

- Node REPL
- Agent-memory, using Engrim
- Headroom
- DBHub
- Chrome DevTools
- Playwright
- NixOS
- Qartez

Pi also retains its existing Exa and OpenAI Developer Docs connections. Copilot,
VS Code and the shared MCP JSON use the same stable commands.

## Dependencies

Nix installs the server packages. Headroom uses the pinned macOS ARM64 wheels
from [Headroom 0.41.0](https://pypi.org/project/headroom-ai/0.41.0/).

Home Manager links local MCP commands under `~/.local/bin`. Client
configurations use these absolute paths, derived from the configured home
directory. Package updates change the link targets without changing the MCP
configuration.

On Loki, Node REPL uses the native `cua_node` runtime from an installed
Codex.app or ChatGPT.app in `/Applications` or `~/Applications`. The launcher
checks for the runtime and reports a missing installation. It does not use
Wodan's Linux executables. This provides the JavaScript MCP server;
browser-plugin setup inside the desktop app remains separate.

On Linux, Nix supplies the Node REPL runtime and a stable Chromium link. The
shared `modules/home/codex-mcp.nix` module retains the native Codex Node REPL,
browser plugins and CUA launcher on Wodan, Frigg and Bragi. CUA remains disabled
in the client configuration, matching its previous setting.

On Loki, the browser servers require an installed Google Chrome. Both start
headless, isolated browser sessions. Chrome DevTools usage statistics and CrUX
requests are disabled.

DBHub uses `~/.config/dbhub/local.toml` and a separate SQLite sandbox at
`~/.local/share/dbhub/local.sqlite`. It does not connect to Wodan's database or
other databases. The sandbox directory has mode 700.

## Activation

Apply each machine's existing NixOS, Home Manager or nix-darwin configuration.
The shared `mkLoki` constructor includes this setup, including when the work
repository supplies a different username or home directory.

Activation merges the eight servers into `~/.codex/config.toml` and the native
v2 `mcp.servers` section in `~/.config/opencode/opencode.jsonc`. Existing model,
provider and unrelated MCP settings are retained. First-change backups have the
suffix `.before-mcp`. OpenCode JSONC comments are accepted; the updated file is
written as formatted JSON. A symlink is replaced locally, preserving its
original target. Pi receives its connections through its native Nix module.

Engram and Engrim remain memory backends behind the `agent-memory` command. The
migration removes their old separate Codex registration names, leaving their
databases untouched. LeanCTX's registration is removed separately because
Headroom replaced that integration.

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

The tests evaluate all six machine homes and a custom work username. They check
stable paths for every local Pi server, retain the special Codex launchers on
Wodan, Frigg and Bragi, and exercise configuration preservation, backups,
idempotence and malformed input. Static client launchers also run with a home
directory containing spaces and no usable PATH. The macOS Node REPL launcher
runs against an app fixture. Real macOS server connections still need a check on
Loki after activation.
