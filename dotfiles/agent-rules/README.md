# agent-rules

A bit of a curious setup: I link `AGENTS.md` to `~/AGENTS.md`, but also to the
`.codex/`, `.pi/`, `.claude/`, and `.copilot/` directories. This provides one
source of truth while keeping the rules available to each agent.

I also link the whole `agent-rules/` directory to `~/agent-rules/` for easy
access to the rules and related files.

The references in `AGENTS.md` start from the home directory. Without `$HOME`,
new threads would search locally and fail to find the referenced `@file`.
