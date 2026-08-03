# LeanCTX

Use LeanCTX as the shared context-engineering layer for coding agents.

- Prefer `ctx_read`, `ctx_search`, `ctx_tree`, and `ctx_shell` when these MCP
  tools are available.
- Use `ctx_compose` for a compact task-oriented codebase overview and
  `ctx_retrieve` when compressed output must be expanded.
- Keep Qartez as the primary graph-aware code-intelligence tool; use LeanCTX for
  compressed reads, searches, shell output, and cross-agent context.
- Use native editing tools for file modifications.
- When MCP tools are unavailable, run shell commands through
  `lean-ctx -c "<command>"` when compression is useful.
- Do not enable the request proxy, cloud sync, telemetry, or configuration
  mutation commands unless the user explicitly asks for them.
