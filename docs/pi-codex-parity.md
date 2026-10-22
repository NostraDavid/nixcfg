# Pi and Codex feature checklist

This configuration targets the local coding workflow of Codex CLI. Pi remains
Pi: it uses its own model providers, sessions, extensions, and authentication.
The pinned runtime is Pi 1.3.0. Its SDK and local extensions use TypeScript.

A checked item is available in the pinned runtime or integrated here. The
verification section separates executable checks from documented native features
and live checks. No paid model request or cloud job is needed for the local
checks.

## Native Pi capabilities

- [x] Read, edit, and write files, and run shell commands.
- [x] Search files with `grep`, `find`, and `ls`.
- [x] Read global and repository `AGENTS.md` instructions.
- [x] Discover the shared `~/.agents/skills` and project `.agents/skills`
      libraries where those libraries are installed.
- [x] Load skills on demand and invoke `/skill:name` explicitly.
- [x] Select providers, models, and reasoning effort with `/model` and
      `/thinking`.
- [x] Preserve the existing Tensorx provider and DeepSeek model configuration.
- [x] Accept images and file attachments, subject to model support.
- [x] Steer active work and queue follow-up messages.
- [x] Save, resume, fork, and navigate session history.
- [x] Compact context automatically or with `/compact`.
- [x] Run non-interactively with `--print`, JSON output, or RPC.
- [x] Load TypeScript extensions, prompt templates, themes, and Pi packages.
- [x] Require project trust before loading executable project configuration.
- [x] Connect native stdio and HTTP MCP servers, including OAuth where
      supported.
- [x] Execute JavaScript tool orchestration through native `codemode` and find
      deferred tools through native `tool_search`.

## Integration added in nixcfg

- [x] Install and configure the same pinned Pi runtime through the shared
      development core on NixOS, Debian with Home Manager, and macOS.
- [x] Keep editable settings, extensions, agent roles, and prompts in dotfiles.
- [x] Use native MCP instead of the old `pi-mcp-adapter` package.
- [x] Use the shared `~/.local/bin/mcp-*` launchers for local servers, including
      Qartez, durable agent memory, and Headroom. Configure official OpenAI
      documentation by URL in the native `mcp.json` format.
- [x] Configure Exa's hosted MCP service for public web search and page
      fetching. Anonymous access needs no API key and has rate limits. Search
      queries and requested URLs go to Exa.
- [x] Link `~/.pi/agent/settings.json` and `~/.pi/agent/mcp.json` directly to
      dotfiles. Home Manager installs the platform-specific command wrappers.
      Work configuration can select its own directly linked MCP file, and native
      project `.pi/mcp.json` entries override user-level servers.
- [x] Disable shell history through the Pi launch environment.
- [x] Add `/plan`, `/plan on`, and `/plan off` with a tool-level read-only gate.
- [x] Block shell execution, file mutation, MCP calls, codemode, tool search,
      and subagents while plan mode is active.
- [x] Add `update_plan`, a visible checklist, and session-branch-aware progress.
- [x] Reject plans with multiple simultaneous `in_progress` steps.
- [x] Add `request_user_input` with choices and free-text answers. Cancellation
      and non-interactive execution never count as an answer or approval.
- [x] Add `/review` with read-only Git inspection of tracked diffs and untracked
      file status. External diff commands and text-conversion programs are
      disabled.
- [x] Load the subagent extension shipped with the pinned Pi package instead of
      maintaining a copy of its process management and rendering code.
- [x] Provide scout, planner, reviewer, and worker role definitions.
- [x] Expose upstream subagent single-task, parallel, and chain modes, model
      inheritance, streaming output, and cancellation. Runtime registration is
      tested; provider-backed delegation still needs a live check.
- [x] Add `/commit` and `/test` prompts that use repository conventions and
      verify Git identity before committing.
- [x] Install `pi-term@0.1.1` and tmux for interactive PTY sessions. The `term`
      tool starts commands, reads output, sends input, lists sessions, and stops
      them. `/term` provides manual access. Terminals survive tool calls and
      `/reload`, but close when their owning Pi session ends or is replaced.
- [x] Add `/worktree [branch or task]` using ordinary Git worktrees and the
      installed wt or Worktrunk skill. Subagents accept a worktree path as
      `cwd`, including on individual parallel tasks. No extra manager is needed.
- [x] Check local extensions automatically against the pinned SDK in a commit
      hook.

## Remaining differences

- [ ] Codex multi-agent mailboxes and exact `spawn_agent`, `send_message`, and
      `wait_agent` semantics. The upstream subagent tool supports delegated
      batches and chains, not that protocol.
- [ ] A live model-backed subagent run and checks on physical macOS and Debian
      hosts.

## Intentionally out of scope

The user excluded these features on 2026-10-20:

- Codex-equivalent OS sandboxing and per-command approvals. The existing plan
  gate remains enabled. It is not an operating-system security boundary.
- Codex Cloud, hosted jobs, cloud handoff, and scheduling.
- Codex app integrations, desktop and IDE interfaces, account-specific services,
  and marketplace plugins.

Ordinary Git worktrees are in scope. A Codex-style worktree manager and UI are
not required. Worktree creation is explicit and does not change the current Pi
session's directory. Worktrees are never removed automatically.

## Use it

Apply the host or Home Manager configuration, then start a new `pi` process. Use
`/reload` for later edits to the linked extensions and prompt files.

Edit the linked `settings.json` and `mcp.json` sources to change native Pi
configuration. Start a new Pi process to load the changes. No Nix switch is
needed for dotfile edits. Run `pi update --extensions` to reconcile installed
packages. Tensorx tracks its npm release, while `pi-term` stays pinned to 0.1.1.

The MCP dotfile contains the public service URLs and portable local launcher
names. Machine-specific arguments belong to the `~/.local/bin/mcp-*` wrappers.
Use `pi mcp list` to inspect the configured connections without loading
extensions. The old `services` extension is removed.

An extension that registers `/mcp`, including the old `pi-mcp-adapter`, replaces
Pi's built-in MCP support. Remove that adapter from user or project package and
extension settings. Also remove `-builtin:mcp` from extension settings and omit
`--no-mcp` when native connections are wanted. Use `pi config` to inspect
enabled extensions, then restart Pi. The Mac that reported the registration
error was not accessed directly; these replacement and disablement conditions
were reproduced locally.

| Task                                                 | Command or tool                                                 |
| ---------------------------------------------------- | --------------------------------------------------------------- |
| Explore and plan without executing or changing files | `/plan on`                                                      |
| Return to execution                                  | `/plan off`                                                     |
| Review uncommitted changes                           | `/review`                                                       |
| Review a branch or focus on a topic                  | `/review changes against master, focusing on authentication`    |
| Record progress                                      | Ask the agent to use `update_plan`                              |
| Ask structured questions                             | `request_user_input`                                            |
| Delegate work                                        | Ask for the `subagent` tool and name a role                     |
| Inspect MCP connections                              | `/mcp`                                                          |
| Search the web or read a page                        | Discover Exa tools with `tool_search`, then call via `codemode` |
| Start or interact with a background terminal         | `term` with `start`, `read`, `send`, `list`, or `kill`          |
| Open a background terminal manually                  | `/term <name>`                                                  |
| Prepare an isolated checkout                         | `/worktree <branch or task>`                                    |
| Add a work-only MCP server                           | `pi mcp add ...`                                                |
| Commit or run relevant checks                        | `/commit` or `/test`                                            |
| Inspect session usage                                | `/session`                                                      |

Plan mode deliberately excludes MCP and JavaScript orchestration because those
can reach mutating tools. Its read-only tools can still read files available to
the user. A model cannot switch plan mode off; use `/plan off` yourself.
Already-running commands finish before the mode changes. Subagents run in
separate processes with separate context, but share the filesystem unless you
assign separate working directories. Role prompts and tool selections do not
provide an OS sandbox.

Terminal names are shared across Pi processes. Use a unique name per project and
worktree, and use the `cwd` argument when starting a terminal in a worktree. On
Linux, `/term` prints a `tmux attach` command. On macOS, it tries Ghostty and
then Terminal.app. Plan mode blocks the model's `term` tool and Exa calls.

Nix installs the launchers and direct dotfile links. Pi and your work
configuration retain credentials, model stores, and session history. Local
server modules install their command wrappers; the native MCP file selects which
servers Pi loads. Check `/mcp` or `pi mcp list` to verify actual connectivity;
valid configuration does not establish a working connection.

## Verify

Run `node --test checks/pi-parity.test.mjs`. It builds or locates the pinned Pi
package for the current platform and loads its real SDK. The tests cover tool
strict TypeScript checking, registration, native MCP connection and tool
discovery, native RPC command discovery, plan-mode restrictions, restoration
across session branches, invalid state, cancelled questions, and real local Git
diffs. They use temporary directories and avoid provider authentication.

The worktree prompt is checked through Pi's real resource loader. To include the
interactive terminal integration test after installing configured packages, run:

```bash
PI_TEST_TERM_PACKAGE="$HOME/.pi/agent/npm/node_modules/pi-term" node --test checks/pi-parity.test.mjs
```

The terminal test uses a separate tmux server. It checks an interactive command,
input and output across calls, existing-session reuse, and cleanup. It does not
open a viewer or touch the user's tmux sessions.

The MCP regression test starts a disposable local stdio server through native
`mcp.json`, verifies its connected state and discovered tool through
`pi mcp
list`, and checks that a real Pi session loads `builtin:mcp` without
extension errors. Remote services are disabled for this test.

On 2026-10-20, live checks confirmed that Exa exposes both configured tools,
returns public web search results, and fetches the Git worktree documentation.
The interactive terminal test passed with pi-term 0.1.1 and Pi 1.3.0. Tensorx
was updated locally to 1.1.0.

The native feature inventory was checked against the documentation shipped with
Pi 1.2.0, with integration checks against the currently pinned SDK. Home
Manager/NixOS/nix-darwin evaluation is checked separately during implementation.
These checks do not prove remote service access or model quality.

Sources: [Codex CLI features](https://developers.openai.com/codex/cli/features),
[Pi documentation](https://github.com/earendil-works/pi/tree/v1.2.0/packages/coding-agent/docs),
[upstream subagent extension](https://github.com/earendil-works/pi/tree/v1.2.0/packages/coding-agent/examples/extensions/subagent),
and
[Pi security boundaries](https://github.com/earendil-works/pi/blob/v1.2.0/packages/coding-agent/docs/security.md).

Added services: [Exa MCP](https://github.com/exa-labs/exa-mcp-server) and
[pi-term](https://github.com/jainam-bhavasar/pi-term).
