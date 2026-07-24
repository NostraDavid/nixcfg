# Headroom

Use Headroom as an optional model-request compression layer for API-based agent
sessions, especially for large tool outputs, JSON, logs, RAG results, files, or
long conversation context. It is separate from the shell-output policy:
LeanCTX, RTK, and Snip remain ordered according to `cli-proxy-policy.md`.

Prefer Headroom when an API client such as TensorX or another OpenAI-compatible
or Anthropic-compatible provider has been explicitly routed through the local
proxy. Do not assume that a Codex subscription session uses the same API path;
test authentication, streaming, tool calls, and response fidelity before
adopting a new route.

- Avoid compressing the same content repeatedly across LeanCTX and Headroom
  when that would remove useful detail.
- Keep Engram as the canonical cross-session memory; do not also enable
  Headroom memory or learning writes by default.
- Treat `headroom doctor`, performance reports, and the dashboard as
  diagnostics only after a Headroom route exists.
- Never expose provider credentials in commands, logs, memory, or instruction
  files.
- Remember that a local proxy compresses locally, but the resulting request is
  still sent to the configured external provider.

Do not run `headroom deploy`, `headroom wrap`, `headroom unwrap`,
`headroom mcp install`, or `headroom learn --apply`, and do not persist proxy or
provider configuration, unless the user explicitly asks for that mutation.
