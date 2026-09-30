# Semble

Use `semble` for focused code search when plain text search is too broad.

```bash
semble search "where is package update logic handled?"
semble search "vscode package definition"
```

Prefer it for semantic questions about code location or behavior. Use `rg` for
exact strings, symbols, paths, and fast mechanical checks.

The development profile installs `semble` on x86_64 Linux. On other platforms,
where its tree-sitter language-pack wheel is unavailable, fall back to `rg`.

Run `semble --help` for the current commands.
