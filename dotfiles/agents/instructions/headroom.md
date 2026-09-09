# Headroom

Use the standalone Headroom MCP server for explicit compression of large raw
tool outputs, JSON, logs, or retrieved documents. Use ordinary file and search
tools for routine work; avoid compressing already compressed content.

Call `headroom_compress` with `content` containing the raw text. Keep the
returned `hash` with the result. Before relying on omitted values, exact
wording, or source to edit, call `headroom_retrieve` with that hash. Keep the
original source until retrieval succeeds; an expired hash requires returning to
the source. Call `headroom_stats` for compression statistics.

Nix installs Headroom independently. Clients start
`headroom mcp serve --transport stdio` on demand. Local compression needs no
model-traffic proxy or API credentials. A proxy-unreachable warning alone does
not invalidate successful local compression or retrieval. Use the backend in
`memory.md` for durable memory. Enable a proxy or Headroom learning only when
the user explicitly requests it.
