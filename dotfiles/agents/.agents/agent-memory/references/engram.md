# Engram procedure

Use the available Engram MCP tools to search project context, save observations,
and save session summaries for substantial unfinished work. Retrieve the full
observation before relying on a truncated search result.

CLI fallbacks:

```bash
engram search "<query>"
engram save "<title>" "<observation>"
engram context
```

Engram is not an automatic chat backup: only captured observations and summaries
survive deletion. Enable Engram Cloud, Git sync, passive capture, or run
`engram setup` only when the user explicitly requests that configuration.
