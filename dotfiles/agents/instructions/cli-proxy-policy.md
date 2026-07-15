# CLI Proxy Policy (RTK primary, Snip fallback)

This is the source of truth for command proxy behavior across Codex and Copilot.

## Policy

1. Use `rtk` as the primary proxy for shell commands.
2. If `rtk` does not support a command, fall back to `snip`.
3. If neither `rtk` nor `snip` is used, explicitly state why the command is
   being run directly.

## Preferred

```bash
rtk git status
rtk go test ./...
```

## Fallback

```bash
snip -- git status
snip -- go test ./...
```

## Notes

- Keep errors and essential output visible.
- Do not force `snip` first when `rtk` works.
- If you bypass both proxies, briefly explain why, for example when running `git
  diff` directly to compare branches.
- All other instruction files should refer to this file for proxy order.
