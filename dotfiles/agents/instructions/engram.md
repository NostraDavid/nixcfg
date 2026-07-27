# Engram

Use Engram as the canonical durable memory shared across coding clients. Store
knowledge that will remain useful after the current chat is deleted or
compacted, such as architecture decisions, non-obvious bug causes, conventions,
and reusable discoveries.

When the Engram MCP tools are available:

- search for relevant memories at the start of work where prior decisions may
  matter;
- save concise observations with what changed or was learned, why it matters,
  and where it applies;
- save a session summary for substantial unfinished work that another session
  must resume; and
- retrieve the full observation before relying on a truncated search result.

CLI fallbacks include:

```bash
engram search "<query>"
engram save "<title>" "<observation>"
engram context
```

Do not save routine command output, transient progress, full chat transcripts,
credentials, secrets, or unnecessary personal data. Engram is not an automatic
chat backup: only captured observations and summaries survive deletion.

Use Beads for tasks, status, blockers, and ownership. Use Engram for decisions,
discoveries, conventions, and handoff knowledge. Do not enable Engram Cloud, Git
sync, passive capture, or run `engram setup` unless the user explicitly requests
that configuration.
