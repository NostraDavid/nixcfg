---
name: nav
description: Choose code navigation tools for symbols, cross-file impact, and structural searches or rewrites with ast-grep.
---

# Code navigation

Choose the smallest on-demand CLI that answers the question. Bound searches to
source directories, honor ignore files, and keep generated dependency trees such
as `.direnv`, `.venv`, `node_modules`, and build output out of recursive scans.
Inspect matches before editing and run the affected project's checks afterward.

| Question                                           | Tool                                                                   |
| -------------------------------------------------- | ---------------------------------------------------------------------- |
| Where is a path or literal?                        | `fd`, `rg`, or `git grep` for tracked files                            |
| Which source block is relevant?                    | `probe search` and `probe extract`                                     |
| Which symbols does a file define?                  | `ctags` or `probe symbols`                                             |
| Where does a syntax pattern occur?                 | `ast-grep`; `tree-sitter` with a configured grammar for custom queries |
| What changed or who changed it?                    | `git log -S`, `git log -G`, `git log --follow`, and `git blame`        |
| How large or complex is the code?                  | `cloc --vcs=git` and `lizard` on explicit source paths                 |
| What does a natural-language description refer to? | `semble search` when available, otherwise refine `probe search`        |

Ranked search results are candidates, not proof of absence. Verify absence with
an exhaustive text or structural search. Symbol names and syntax matches do not
establish reference identity. Check scope and imports at callers; use the
project's language server or compiler for exact semantic references and types.
For dynamically composed Nix modules, prefer the repository's evaluated module
graph when one exists.

## Definitions, history, and complexity

These commands print results without creating a persistent tags index:

```bash
ctags --options=NONE --output-format=json --fields=+nK -f - src/example.py
git grep -n 'symbol_name' -- src tests
git log -S 'symbol_name' -- src/example.py
git log -G 'pattern' -- src/example.py
git blame -L 20,60 -- src/example.py
cloc --vcs=git
lizard -C 15 -L 100 src/ -x '*/.direnv/*' -x '*/node_modules/*'
```

Use the installed Universal Ctags, identified by `ctags --version`; operating
systems may ship a different `ctags`. Ctags describes definitions and scope, not
a complete call graph. The pinned Ctags and Probe symbol parsers do not support
Nix. Probe falls back to line-by-line text there; empty names with kind `text`
are not parsed symbols. Use `ast-grep --lang nix`, `rg`, and evaluated module
graphs for Nix. Lizard also excludes Nix. Its complexity counts are estimates; a
nonzero exit can mean a configured threshold was exceeded. Choose its source
paths explicitly and inspect warnings before treating them as runtime failures.
Add `-Eduplicate` for a focused duplicate-code investigation.

## Structural edits

Call `ast-grep` by its full name because `sg` can be a system command. Pass an
explicit language and quote patterns so the shell preserves `$` metavariables.
`$PACKAGE` matches one AST node; `$$$ARGS` matches zero or more nodes.

```bash
ast-grep run --lang nix --pattern 'stable.$PACKAGE' features/
ast-grep run --lang nix --pattern 'stable.ast-grep' --rewrite 'unstable.ast-grep' features/
```

The rewrite command previews changes. Inspect the matches and preview before
adding `--update-all`; review the diff and run relevant checks afterward. For
absence checks, account for hidden files and ignores with scoped `--no-ignore`
flags. Use `rg` and direct edits if a language is unsupported.
`tree-sitter parse` and `tree-sitter query` need a registered grammar; use
`ast-grep` or Probe when no matching grammar is configured.

For ranked discovery, AST extraction, syntax queries, and limits, read
[the Probe workflow](references/probe.md). Use plain Probe CLI commands for this
workflow. Probe LSP daemons and repository-wide indexing require a task that
explicitly needs those modes. Plain CLI navigation needs no background watcher.

Keep durable discoveries in the backend selected by
`~/.agents/instructions/memory.md`.
