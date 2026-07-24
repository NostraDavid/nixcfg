# CLI Proxy Policy (LeanCTX, RTK, Snip)

This is the source of truth for command proxy behavior across Codex and Copilot.

## Policy

1. Use `lean-ctx -c` as the primary context and output-compression layer.
2. If LeanCTX is unavailable, disabled, unsuitable for complex shell quoting,
   or does not preserve the required output, fall back to `rtk`.
3. If RTK does not support the command, fall back to `snip`.
4. If none of LeanCTX, RTK, or Snip is used, explicitly state why the command
   is being run directly.

## Preferred

```bash
lean-ctx -c "git status"
lean-ctx -c "go test ./..."
```

## Fallback

```bash
rtk git status
rtk go test ./...

snip git status
snip go test ./...
```

## Notes

- Keep errors and essential output visible.
- Do not stack all three proxies around the same command.
- Use `lean-ctx raw "<command>"` when exact uncompressed output is required but
  the command should remain visible to LeanCTX.
- Do not force Snip when RTK works, or RTK when LeanCTX already handles the
  command correctly.
- If you bypass all three layers, briefly explain why, for example when running
  a control command for a compression benchmark.
- All other instruction files should refer to this file for proxy order.
