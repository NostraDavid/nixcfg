# Human-in-the-loop reproduction plans

Use the HITL helper only when the reproduction requires actions an agent cannot
automate. The helper keeps prompts on stderr and emits captured answers as
`KEY=VALUE` lines on stdout, so the debugging agent can parse the result.

Write a temporary TOML plan:

```toml
title = "Export error reproduction"

[[prompts]]
type = "step"
instruction = "Open the app at http://localhost:3000 and sign in."

[[prompts]]
type = "capture"
key = "ERRORED"
question = "Click Export. Did it throw an error? (y/n)"

[[prompts]]
type = "capture"
key = "ERROR_MSG"
question = "Paste the error message (or none)."
required = false
```

Capture keys must be unique uppercase identifiers. Captures are required unless
`required = false` is set.

Validate the complete plan without prompting:

```bash
./scripts/hitl_loop.py run /tmp/export-repro.toml --dry-run
```

Then run it in the user's terminal:

```bash
./scripts/hitl_loop.py run /tmp/export-repro.toml
```

Captured values are printed to stdout. Keep secrets, credentials, and personal
data out of questions and answers. Delete temporary plans after the
investigation when they contain sensitive reproduction context.
