# LeanCTX rules

<!-- lean-ctx-rules -->
<!-- version: 8 -->

lean-ctx shadow mode: native file/search/shell calls auto-route to ctx_* — no tool-mapping needed.
Exclusive tools (no native trigger): ctx_compose (understand code, call first), ctx_search(action=symbol) (exact symbol), ctx_search(action=semantic) (by meaning), ctx_callgraph (callers), ctx_knowledge / ctx_session (memory).
<!-- lean-ctx-compression -->

OUTPUT STYLE: concise

- Bullet points over paragraphs
- Skip filler words and hedging ("I think", "probably", "it seems")
- 1-sentence explanations max, then code/action
- No repeating what the user said

<!-- /lean-ctx-compression -->
<!-- /lean-ctx-rules -->

<!-- lean-ctx -->

## lean-ctx

Prefer lean-ctx MCP tools over native equivalents for token savings.

For compression you can rely on regardless of your Codex surface (CLI, Desktop, or Cloud) or Codex version, route shell commands through `ctx_shell` (or `/nix/store/idnip77gy6jrib5cdqwijr12ravyf1rd-lean-ctx-3.9.12/bin/lean-ctx -c "<cmd>"`), file reads through `ctx_read`, and code search through `ctx_search`. Hook-driven auto-compression may also be active, but the MCP/CLI tools are the path that works everywhere — otherwise large outputs (builds, `tsc`, tests, logs) can reach the model uncompressed.

Full rules: `/home/david/.codex/LEAN-CTX.md`
<!-- /lean-ctx -->
