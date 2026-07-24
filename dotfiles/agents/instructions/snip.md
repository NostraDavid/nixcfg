# Snip - CLI proxy

Snip is the third command-proxy fallback, after LeanCTX and RTK. Invoke it with
the original command and arguments unchanged:

```bash
snip git status
snip go test ./...
```

Snip passes commands without a matching filter through unchanged and preserves
the underlying command's exit code. Its declarative filters are stored under
`~/.config/snip/filters/`.
