# Headroom through LeanCTX

Use Headroom for explicit compression of large raw tool outputs, JSON, logs, or
retrieved documents. Keep ordinary file reads and searches in LeanCTX; avoid
compressing content that LeanCTX has already compressed.

Discover Headroom with `ctx_tools` using `action = "find"` and
`query = "headroom"`. If `ctx_tools` is not exposed, invoke it through
`ctx_call` with `name = "ctx_tools"` and the same arguments.

Call it through the LeanCTX gateway:

```json
{
  "action": "call",
  "tool": "headroom::headroom_compress",
  "arguments": { "content": "<raw content>" }
}
```

Keep the returned `hash` with the compressed result. Before relying on omitted
values, exact wording, or source to edit, retrieve the original with
`headroom::headroom_retrieve` and `arguments = {"hash":"<returned hash>"}`. Use
`headroom::headroom_stats` with empty arguments for compression statistics.

LeanCTX 3.10.1 can return `Transport closed` when it reuses a downstream
connection after shutting down that call's runtime. For these Headroom tools,
use a fresh LeanCTX CLI process as the fallback. Write the same gateway JSON to
a temporary file, then run through `ctx_shell`:

```bash
lean-ctx call ctx_tools --project-root /absolute/project/path --json-file /path/to/request.json
```

Remove the temporary request file after use. Keep the original source until
retrieval succeeds; an expired hash requires returning to that source.

Nix supplies Headroom and the gateway starts `headroom mcp serve` on demand.
This integration compresses locally and needs no model-traffic proxy or API
credentials. A proxy-unreachable warning alone does not invalidate a successful
local compression or retrieval. Use the backend selected in `memory.md` for
durable memory. Change provider routing, install separate agent MCP entries, or
enable Headroom learning only when the user explicitly requests those changes.
