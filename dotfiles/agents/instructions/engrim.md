# Engrim

Use Engrim for durable decisions, discoveries, conventions, and handoff state.
At session start, call `engrim_context`; before substantial work, search with
`engrim_recall`. Save concise records with `engrim_add` at meaningful decision
points and before handing unfinished work to another session.

Pass the repository's absolute root as `project` on every MCP call. A shared
server's working directory may differ from the current task's repository. Use
the same root across clients. Reserve global memory for preferences that apply
across projects.

CLI fallback, run from the repository root:

```bash
engrim context
engrim recall --query "<topic>" --detail
engrim add --type decision --summary "<decision>" --detail "<why and where>"
```

Store reusable knowledge, not routine progress, full transcripts, credentials,
or secrets. CTX handles retrieval of original sessions. This configuration uses
explicit memory tools; `engrim_review` cannot establish handoff coverage without
a transcript log. Save the handoff state explicitly.

Engram's existing database remains available for historical lookup when
requested. Switching backends does not migrate or synchronize their data.
