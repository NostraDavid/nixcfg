# AGENTS.md

- @~/.agents/instructions/batch-instructions.md
- @~/.agents/instructions/lean-ctx.md
- @~/.agents/instructions/qartez.md
- @~/.agents/instructions/context7.md
- @~/.agents/instructions/engram.md
- @~/.agents/instructions/commit-style.md
- @~/.agents/instructions/worktrees.md

<!-- lean-ctx-rules -->
<!-- version: 8 -->

lean-ctx shadow mode: native read/search/shell calls auto-route to ctx_* — no
tool-mapping needed. File editing → native Edit/StrReplace (lean-ctx only
handles reads). Exclusive tools (no native trigger): ctx_compose (understand
code, call first), ctx_search(action=symbol) (exact symbol),
ctx_search(action=semantic) (by meaning), ctx_callgraph (callers), ctx_knowledge
/ ctx_session.

<!-- lean-ctx-compression -->

OUTPUT STYLE: concise

- Bullet points over paragraphs
- Skip filler words and hedging ("I think", "probably", "it seems")
- 1-sentence explanations max, then code/action
- No repeating what the user said

<!-- /lean-ctx-compression -->
<!-- /lean-ctx-rules -->
