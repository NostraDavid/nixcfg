# Stable MCP commands on all machines

The `mcp` Den aspect in `features/mcp/default.nix` configures these servers for
Codex, OpenCode and Pi on Wodan, Donar, Frigg, Bragi, Mimir2 and Loki:

- Agent-memory, using Engrim
- DBHub
- Chrome DevTools
- Playwright
- NixOS

Pi also retains its existing Exa and OpenAI Developer Docs connections. Copilot,
VS Code and the shared MCP JSON use the same stable commands.

## Dependencies

Nix installs the server packages. The NixOS MCP server uses stable nixpkgs
because unstable's FastMCP dependency is incompatible with MCP SDK 2.x.

Home Manager installs local MCP commands under `~/.local/bin/mcp-*`. Native
client dotfiles refer to those commands with supported environment expansion or
a `/bin/sh` launcher. Platform-specific arguments belong to the command
wrappers. Package updates change the executables without changing the client
files.

Node REPL is excluded from the OpenCode and Pi dotfiles on every host. On Loki,
the Codex command wrapper disables Node REPL, and Home Manager omits its
runtime.

On Linux, Nix supplies the Codex Node REPL runtime and a stable Chromium link.
The `codex-browser` aspect in `features/codex-browser/default.nix` retains the
native Codex Node REPL, browser plugins and CUA launcher on Wodan, Frigg and
Bragi. CUA remains disabled in the client configuration, matching its previous
setting.

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

The client configurations remain directly linked to their live dotfiles.
Activation never replaces these links with generated copies. Edit the native
client file to select servers; source edits need no Nix switch. A work module
that selects its own configuration must include the wanted MCP entries there.
The existing `opencode-mcp-*` browser names remain aliases for work
repositories.

Pi's Nix wrapper supplies its environment and leaves `settings.json` and
`mcp.json` untouched. The first switch backs up old generated Pi files through
Home Manager's configured backup mechanism. Standalone activation defaults to
`.before-direct-dotfiles` when no backup policy was selected.

Engram and Engrim remain memory backends behind the `agent-memory` command.
Their databases are retained.

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
directory containing spaces and no usable PATH. The tests also verify removal of
existing Node REPL registrations on Loki. Real macOS server connections still
need a check on Loki after activation.
