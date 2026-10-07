---
name: nav
description: Choose code navigation tools for symbols, cross-file impact, and structural searches or rewrites with ast-grep.
---

# Code navigation

Use Qartez through MCP for indexed semantic navigation and cross-file analysis.
Use Serena when Qartez cannot answer, its index is stale or incomplete, or
LSP-backed semantics are required. Use `rg` for exact text and ordinary file
edits for small configuration or documentation changes.

Use `ast-grep` for syntax patterns and structural rewrites. It matches syntax,
not symbol identity. Use Qartez or Serena when scope or references matter.
Call `ast-grep` by its full name because `sg` can also be a system command.

Pass an explicit language and scope searches to the relevant files. Quote
patterns with single quotes so the shell preserves `$` metavariables.
`$PACKAGE` matches one AST node; `$$$ARGS` matches zero or more nodes.

```bash
ast-grep run --lang nix --pattern 'stable.$PACKAGE' modules/home/development/core.nix
ast-grep run --lang nix --pattern 'stable.ast-grep' --rewrite 'unstable.ast-grep' modules/home/development/core.nix
```

The second command previews a package-source change without editing the file.
Inspect matches and the rewrite preview before adding `--update-all` to apply
an intended change. Review the diff and run relevant checks afterward.
When checking absence, account for hidden files and ignore rules with the
appropriate `--no-ignore` flags. If the language is unsupported or the tool is
unavailable, use `rg` and direct edits, and state the limitation.

For ranked discovery or AST extraction without an index, read
[the Probe workflow](references/probe.md). Ranked hits do not prove absence;
confirm absence with exhaustive text or structural search.

Use the available MCP tool descriptions for tool names, parameters, navigation
steps, and tier activation. Select the registered tools in the current client; a
client-specific prefix is not part of the workflow. Avoid repeating a successful
Qartez query in another tool merely for confirmation.

Before semantic edits, inspect the symbol and references, assess important files
with Qartez impact analysis, and preview refactoring operations. Check the
affected files and run proportionate diagnostics or tests after editing. If the
index or language server cannot represent the target, use direct file editing.

Keep durable observations in the backend selected by
`~/.agents/instructions/memory.md`, including when using Serena. Tool setup,
hooks, client configuration, and language-backend changes require an explicit
configuration request.
