---
name: mem
description: Retrieve or record durable decisions, discoveries, and handoff state using the configured Engrim or Engram backend.
---

# Agent memory

Read `~/.config/agent-memory/provider` and load only the matching procedure:

- `engrim`: [Engrim procedure](references/engrim.md).
- `engram`: [Engram procedure](references/engram.md).

Use the `mem` MCP server for that backend, with the documented CLI as
fallback. If the provider is missing or unknown, report that configuration
problem rather than choosing a backend or writing to both.

Follow the retention rules in `~/.agents/instructions/memory.md`. Use the `ctx`
skill when original sessions are needed to establish what happened or why.
Backend switching does not migrate or synchronize existing records.
