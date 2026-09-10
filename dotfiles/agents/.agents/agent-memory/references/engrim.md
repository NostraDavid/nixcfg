# Engrim procedure

At session start, call `engrim_context`; before substantial work, search with
`engrim_recall`. Save records with `engrim_add`.

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

This configuration uses explicit memory tools; `engrim_review` cannot establish
handoff coverage without a transcript log. Save the handoff state explicitly.
Engram's existing database remains available for historical lookup when
requested.
