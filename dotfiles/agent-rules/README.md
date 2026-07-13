# agent-rules

A bit of a curious setup: I link `AGENTS.md` to `~/AGENTS.md`, but also make it
available to Codex, Claude, Pi, and Gemini. This provides one source of truth
while keeping the rules available to each agent.

I also link the whole `agent-rules/` directory to `~/agent-rules/` for easy
access to the rules and related files.

The references in `AGENTS.md` start from the home directory. Without `$HOME`,
new threads would search locally and fail to find the referenced `@file`.

The preventive EU AI Act rule is also loaded directly by clients that do not
follow the `@file` references in `AGENTS.md`:

- Copilot receives it as a personal instruction file.
- OpenCode loads it through the global `instructions` setting.
- Hermes receives it as build-time content appended to its declaratively
  managed `SOUL.md`; the existing Hermes persona remains the first paragraph.

The matching inventory, scope assessment, and review log live in
`docs/ai-governance.md` in this repository.
