# Headroom

Use Headroom through its MCP tools for explicit compression and retrieval of
large tool outputs, JSON, logs, RAG results, files, or long conversation
context. It is separate from the shell-output policy: RTK and Snip remain
ordered according to `cli-proxy-policy.md`.

Headroom is configured in MCP-only mode. It does not proxy model traffic or
compress every request automatically; call its MCP tools when compression is
useful.

- Avoid repeatedly compressing the same content when that would remove useful
  detail.
- Keep Engram as the canonical cross-session memory; do not also enable Headroom
  memory or learning writes by default.
- Proxy diagnostics such as `headroom doctor`, performance reports, and the
  dashboard do not apply unless a separate proxy route is deliberately enabled.
- Never expose provider credentials in commands, logs, memory, or instruction
  files.
- Remember that a local proxy compresses locally, but the resulting request is
  still sent to the configured external provider.

Do not run `headroom deploy`, `headroom wrap`, `headroom unwrap`, `headroom mcp
install`, or `headroom learn --apply`, and do not persist proxy or provider
configuration, unless the user explicitly asks for that mutation.
