---
name: mcporter
description: Discover and call MCP tools from the terminal with mcporter when a task needs CLI access to MCP servers or an agent lacks a native MCP connection.
---

# Call MCP tools from the terminal

Use the agent's native MCP connection when it already provides the required
tool. Use `mcporter` for terminal access, scripts, or a missing native connection.
Install and update the CLI through Nix. Check `mcporter <command> --help` for
the installed version's flags.

Inspect configured servers with `mcporter config list --json`. Inspect a
server's tools with `mcporter list SERVER --schema` before choosing a tool and
its arguments. Use `--args` for JSON payloads and `--output json` for structured
results. Tool calls retain the same authorization requirements as native MCP
calls, including messages, writes, and sensitive data sent to remote servers.

For example, inspect Context7 and resolve a public library:

```bash
mcporter list https://mcp.context7.com/mcp --schema
mcporter call https://mcp.context7.com/mcp.resolve-library-id --args '{"query":"React hooks documentation","libraryName":"react"}' --output json
```

MCPorter can discover existing client configurations. Inspect configuration
sources before changing them. For a one-off connection, pass the server URL or
`--stdio` without persisting it. Keep reusable configuration in the repository's
dotfiles and link it through Home Manager when the task requires it.
Use environment variables for credentials. If authentication is required,
report the server's authentication requirement and use `mcporter auth SERVER`
when authorized.
