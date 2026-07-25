# AGENTS.md

- @~/.agents/instructions/lean-ctx-rules.md
- @~/.agents/instructions/batch-instructions.md
- @~/.agents/instructions/cli-proxy-policy.md
- @~/.agents/instructions/lean-ctx.md
- @~/.agents/instructions/RTK.md
- @~/.agents/instructions/snip.md
- @~/.agents/instructions/probe.md
- @~/.agents/instructions/serena.md
- @~/.agents/instructions/context7.md
- @~/.agents/instructions/engram.md
- @~/.agents/instructions/beads.md
- @~/.agents/instructions/headroom.md
- @~/.agents/instructions/commit-style.md
- @~/.agents/instructions/worktrees.md

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