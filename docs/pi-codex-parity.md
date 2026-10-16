# Pi and Codex feature checklist

This configuration targets the local coding workflow of Codex CLI. Pi remains
Pi: it uses its own model providers, sessions, extensions, and authentication.
The pinned runtime is Pi 1.2.0. Its SDK and local extensions use TypeScript.

A checked item is available in the pinned runtime or integrated here. The
verification section separates executable checks from documented native
features. No paid model request, live remote MCP connection, or cloud job was
used to verify this change.

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
- [x] Register Qartez, durable agent memory, Headroom, and Blender when their
      executables are installed. Register official OpenAI documentation by URL.
- [x] Preserve local and work-specific MCP configuration: entries in
      `~/.pi/agent/mcp.json` override extension-provided servers of the same
      name.
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
- [x] Check local extensions automatically against the pinned SDK in a commit
      hook.

## Remaining differences

- [ ] General live web search. Configure a search MCP service in `mcp.json`;
      OpenAI documentation search is already available, but is not general web
      search.
- [ ] Codex-equivalent OS sandboxing and per-command approval policies on all
      platforms. Plan mode is a tool gate, not an operating-system boundary.
      Pi's Nix module offers optional Linux jail integration; it is not enabled
      here.
- [ ] Persistent PTY command sessions with Codex-style `exec_command` and
      `write_stdin` tools. Pi's native shell tool remains the execution
      interface.
- [ ] Codex multi-agent mailboxes and exact `spawn_agent`, `send_message`, and
      `wait_agent` semantics. The upstream subagent tool supports delegated
      batches and chains, not that protocol.
- [ ] Managed Git-worktree UI and automatic isolation for parallel writers.
      Assign separate worktrees before dispatching workers that could share
      files.
- [ ] Direct reuse of Codex marketplace plugins and ChatGPT app-owned tools. Pi
      packages and ordinary MCP services work; app-private runtimes do not
      transfer.
- [ ] Codex Cloud, its hosted environments, remote task handoff, and scheduling.
- [ ] Codex desktop and IDE interfaces, review panes, and account-specific
      services.
- [ ] A live model-backed subagent run and checks on physical macOS and Debian
      hosts.

## Use it

Apply the host or Home Manager configuration, then start a new `pi` process. Use
`/reload` for later edits to the linked extensions and prompt files.

| Task                                                 | Command or tool                                              |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| Explore and plan without executing or changing files | `/plan on`                                                   |
| Return to execution                                  | `/plan off`                                                  |
| Review uncommitted changes                           | `/review`                                                    |
| Review a branch or focus on a topic                  | `/review changes against master, focusing on authentication` |
| Record progress                                      | Ask the agent to use `update_plan`                           |
| Ask structured questions                             | `request_user_input`                                         |
| Delegate work                                        | Ask for the `subagent` tool and name a role                  |
| Inspect MCP connections                              | `/mcp`                                                       |
| Add a work-only MCP server                           | `pi mcp add ...`                                             |
| Commit or run relevant checks                        | `/commit` or `/test`                                         |
| Inspect session usage                                | `/session`                                                   |

Plan mode deliberately excludes MCP and JavaScript orchestration because those
can reach mutating tools. Its read-only tools can still read files available to
the user. A model cannot switch plan mode off; use `/plan off` yourself.
Already-running commands finish before the mode changes. Subagents run in
separate processes with separate context, but share the filesystem unless you
assign separate working directories. Role prompts and tool selections do not
provide an OS sandbox.

Only the named dotfile resources are managed. Credentials, model stores, session
history, and work-owned `mcp.json` are left to Pi and your work configuration.
Missing optional MCP executables are skipped. Check `/mcp` to verify actual
connectivity; successful registration does not establish a working connection.

## Verify

Run `node --test checks/pi-parity.test.mjs`. It builds or locates the pinned Pi
package for the current platform and loads its real SDK. The tests cover tool
strict TypeScript checking, registration, native RPC command discovery,
plan-mode restrictions, restoration across session branches, invalid state,
cancelled questions, and real local Git diffs. They use temporary directories
and avoid provider authentication.

The native feature inventory was checked against the documentation shipped with
Pi 1.2.0. Home Manager/NixOS/nix-darwin evaluation is checked separately during
implementation. These checks do not prove remote service access or model
quality.

Sources: [Codex CLI features](https://developers.openai.com/codex/cli/features),
[Pi documentation](https://github.com/earendil-works/pi/tree/v1.2.0/packages/coding-agent/docs),
[upstream subagent extension](https://github.com/earendil-works/pi/tree/v1.2.0/packages/coding-agent/examples/extensions/subagent),
and
[Pi security boundaries](https://github.com/earendil-works/pi/blob/v1.2.0/packages/coding-agent/docs/security.md).
