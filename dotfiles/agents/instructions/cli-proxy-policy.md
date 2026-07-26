# CLI Proxy Policy (RTK, Snip)

This is the source of truth for command proxy behavior across Codex and Copilot.

## Policy

1. Use `rtk` as the primary output-compression layer for supported commands.
2. If RTK does not support the command, fall back to `snip`.
3. If neither RTK nor Snip is used, explicitly state why the command is being
   run directly.

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
- If you bypass both layers, briefly explain why, for example when running a
  control command for a compression benchmark.
- All other instruction files should refer to this file for proxy order.
