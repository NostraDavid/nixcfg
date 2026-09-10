---
name: cli-output
description: Use RTK and Snip to compress shell command output, select a supported wrapper, or recover complete failure details.
---

# CLI output

Follow the proxy order in `~/.agents/instructions/cli-proxy-policy.md`. Use the
installed commands' help to check support for the requested operation.

RTK provides dedicated wrappers:

```bash
rtk git status
rtk pytest
rtk cargo test
rtk npm run build
```

Use `rtk gain` for savings statistics. When RTK's tee feature is enabled,
inspect its reported full-output file for failure details instead of rerunning
the command solely for verbose output.

With Snip, pass the original command and arguments unchanged:

```bash
snip git status
snip go test ./...
```

Snip passes commands without a matching filter through unchanged and preserves
the command's exit code. Declarative filters live in `~/.config/snip/filters/`.
