# OpenCode v2

All configured machines install the pinned `opencode-v2` CLI package as
`opencode`. This replaces the v1 CLI entries in the workstation profiles. NixOS
hosts receive it as a system package; the portable Debian and macOS profiles
receive it through Home Manager.

The existing Linux desktop installation also moves to v2 through
`opencode-v2-desktop`, retaining the `opencode-desktop` command and desktop
entry. There is an official v2 desktop build, so the v1 app is replaced rather
than retained. Servers do not gain a graphical application.

## Packages and updates

Both packages pin the same stable **2.x** release. The CLI uses the official
platform-specific `@opencode/cli-*` npm archives with fixed integrity hashes.
Linux binaries are patched for Nix's loader and libraries. The x86-64 builds use
the baseline CPU variant so they do not require AVX2.

CLI platforms are x86-64 Linux, ARM64 Linux, Apple Silicon macOS, and Intel
macOS. The desktop package uses the official x86-64 Linux AppImage, matching our
current graphical NixOS hosts. It includes its matching v2 CLI sidecar.

The CLI wrapper disables automatic updates, and the workstation configuration
retains its disabled update setting. From the Linux maintenance checkout, run:

```bash
just pkg-update opencode-v2
```

This updates both packages together, refreshes the four platform-specific CLI
integrity hashes and desktop checksum, and builds both packages. The desktop
entry point `just pkg-update opencode-v2-desktop` runs the same paired updater.
Missing downloads or invalid metadata leave the definitions unchanged; a failed
build restores both files, including pre-existing local changes. An unchanged
release does not trigger another build. The script refuses prereleases and other
major versions.

For a preview or a specific release, use:

```bash
./scripts/update-opencode-v2.sh --dry-run
./scripts/update-opencode-v2.sh 2.0.32
```

The preview performs discovery and prefetching into the Nix cache, but does not
edit the package definitions or build them. After updating, rebuild the target
host. Avoid using `opencode upgrade` to replace a Nix-managed installation.

## Configuration migration

The [upstream migration guide](https://opencode.ai/v2/docs/migrate-v1/) keeps
supported v1 configuration compatible. Our v2 configuration therefore retains
the existing agents, models, provider settings, MCP commands, and permissions.
The unsupported top-level `subagent_depth` setting moves under `experimental`.
The configuration uses native v2 `agents`, with `system` and ordered
`permissions` rules instead of the deprecated `agent`, `prompt`, and
`permission` fields. It also uses `update: "disable"`, `providers` with
`package` and `settings`, `snapshots`, provider-use `policies`, and
`mcp.servers` with `disabled` and separate timeout fields. Complete normalized
configuration snapshots were compared before and after conversion; the effective
settings are identical. The orchestrator prompt refers to the renamed `subagent`
tool.

The managed configuration is
`dotfiles/opencode-2.0.32/.config/opencode/opencode.jsonc`. It uses Tensorx with
GLM 5.3 Flash for the primary agent and DeepSeek V4.1 Flash for the worker.
Provider policies allow only Tensorx for both agents. Authentication remains
local; no credential is stored in the file.

The retired v1 and work-proxy configurations have been removed. The workstation
link selects the remaining personal configuration.

## MCP servers

The personal profile includes all ten servers declared in the active Codex
configuration on Wodan: `agent-memory`, `blender`, `chrome-devtools`, `dbhub`,
`headroom`, `nixos`, `node_repl`, `openaiDeveloperDocs`, `playwright`, and
`qartez`. The disabled `cua_repl` entry in the old Codex dotfile is not an
active server.

DBHub uses the [local SQLite sandbox](dbhub-local.md).

Wodan installs `opencode-mcp-*` launchers that reuse its pinned browser
executables and flags. They keep Nix store paths out of the editable JSON file.
The Node REPL launcher uses the pinned ChatGPT package's Node runtime and module
directory. Standalone MCP initialization and JavaScript execution work; the
ChatGPT app's private browser bridge is not configured for OpenCode.

Apply the Nix configuration before restarting OpenCode so the new launchers and
server executables are available. Then use `opencode mcp list` to check actual
connections. Blender still requires the local Blender service for scene work.

## Queue plugin

The configuration pins
[opencode-queue](https://github.com/mirsella/opencode-queue/tree/v2.0.2) to
2.0.2, which requires OpenCode v2.0.27 or newer. OpenCode installs the npm
plugin when it loads. Restart the background service and reopen the client after
changing plugins.

Use `/queue text` or `/q text` to queue input, `/queue:list` to inspect it, and
`/queue:stop` or `/queue:start` to pause or resume replay. V2 requires explicit
queue commands. Ordinary input is not automatically queued, and trailing
`text /queue` syntax is not supported. The plugin stores its queue in OpenCode's
user data directory; the repository does not manage that file.

V2 still reads `~/.config/opencode/AGENTS.md` and the existing skills. Provider
credentials are not changed or stored in the repository. The portable profiles
keep their existing user configuration.

V2 does not provide v1's LSP diagnostics or a Core `doom_loop` permission
action. Its server API and plugin API have changed. Integrations outside this
repository that call v1 endpoints must be updated separately.

## Activate and verify

Before first use, close v1 clients and back up your existing OpenCode config and
data directories. Nix activation does not migrate or delete session data; the
application controls any migrations when first started. The CLI preserves the
older nixpkgs `opencode-stable.db` choice when that file exists and the
canonical `opencode.db` does not. An explicit `OPENCODE_DB` override takes
precedence.

Activate the NixOS or Home Manager configuration on the target machine, then
check the selected executable:

```bash
command -v opencode
opencode --version
```

The version should report the pinned `opencode v2.x.y`. A prior curl/npm
installation earlier in `PATH` can still select another executable; remove that
installation or correct `PATH` if necessary.

V2 clients normally start or reuse a per-user background service. Use
`opencode service status` to inspect it and `opencode service restart` to load a
newly installed binary or changed configuration, including removed MCP servers.
Reopening the client alone can reuse the service's cached configuration. Run
`opencode debug config` after the restart to verify the loaded configuration.
`opencode --standalone` uses a private server instead. Terminal-client
preferences move from legacy `tui.json` files to `~/.config/opencode/cli.json`
on first startup. Home Manager links this writable file to
`dotfiles/opencode-2.0.32/.config/opencode/cli.json`, so changes made in the TUI
also update the checkout. The client uses this file for its terminal
preferences.

The managed `opencode.jsonc` contains the MCP configuration. Home Manager no
longer writes a second `opencode.json` for OpenCode. V2 still reads both names,
so archive an old local `opencode.json` outside the configuration directory
after checking for settings absent from the managed file.

V2 loads global and project `AGENTS.md` files, plus files listed in
`instructions`. Our global file links to the shared agent instructions. Qartez
handles code navigation and Headroom handles output compression through MCP. The
old `rules/lean-ctx.md` belongs to the removed LeanCTX integration and is not
part of this instruction setup.

Verify models and credentials, agent selection, MCP connectivity, permissions,
and a disposable session before relying on the migration for ongoing work. For
rollback, restore the earlier Nix generation and config/data backups; do not run
v1 against data or native v2-only configuration that v2 has migrated.

## Checks

```bash
bash checks/test-opencode-v2.sh
nix eval --impure --json --file checks/tooling.nix
```

The CLI test uses temporary XDG directories and private service instances. It
checks the personal configuration through real v2 normalization, provider
isolation for both agents, retained restrictions, database path selection, and a
running v2 API without model calls. The tooling check asserts installation on
every NixOS host, Debian and macOS, checks the desktop replacement, and rejects
remaining v1 entries in the managed workstation profiles. macOS/ARM execution
and live provider credentials require validation on those machines.
