# Semble

Use `semble` for focused code search when plain text search is too broad.

```bash
semble search "where is package update logic handled?"
semble search "vscode package definition"
```

Prefer it for semantic questions about code location or behavior. Use `rg` for
exact strings, symbols, paths, and fast mechanical checks.

The declarative profile installs `semble` on x86_64 Linux. On other platforms,
where its tree-sitter language-pack wheel is unavailable, fall back to `rg`.

## semble -h

```docs
usage: semble [-h] {search,find-related,init,savings} ...

positional arguments:
  {search,find-related,init,savings}
    search              Search a codebase.
    find-related        Find code similar to a specific location.
    init                Write a semble sub-agent file for your coding agent.
    savings             Show token savings and usage stats.

options:
  -h, --help            show this help message and exit
```
