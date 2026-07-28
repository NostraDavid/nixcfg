# CLI Proxy Policy (RTK, Snip)

This is the source of truth for command proxy behavior across Codex and Copilot.

## Scope

This policy applies only to commands executed through a shell. RTK and Snip
compress command output; they do not replace or wrap MCP calls.

For code intelligence, use Qartez first and Serena as the LSP-backed fallback.
Use `rg` for exact text and Probe for structural or ranked discovery when those
are a better fit. If that workflow invokes a shell command, apply the RTK → Snip
→ direct order to that command.

## Policy

1. Use `rtk` as the primary output-compression layer for supported commands.
2. If RTK does not support the command or does not preserve required output,
   fall back to `snip`.
3. If Snip also does not preserve required output, run the command directly and
   explicitly state why.

## Preferred

```bash
rtk git status
rtk go test ./...
```

## Fallback

```bash
snip git status
snip go test ./...
```

## Notes

- Keep errors and essential output visible.
- Do not stack both proxies around the same command.
- Do not force Snip when RTK works.
- If you bypass both layers, briefly explain why, for example when reading an
  exact diff that both proxies reduce to a summary.
- All other instruction files should refer to this file for proxy order.
