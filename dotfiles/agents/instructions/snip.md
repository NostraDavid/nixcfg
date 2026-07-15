# Snip - CLI proxy

Invoke snip with the original command and arguments unchanged:

```bash
snip git status
snip go test ./...
```

Snip passes commands without a matching filter through unchanged and preserves
the underlying command's exit code. Its declarative filters are stored under
`~/.config/snip/filters/`.
