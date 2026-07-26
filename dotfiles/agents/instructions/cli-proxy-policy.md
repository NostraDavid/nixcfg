# CLI Proxy Policy (RTK, Snip)

This is the source of truth for command proxy behavior across Codex and Copilot.

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
