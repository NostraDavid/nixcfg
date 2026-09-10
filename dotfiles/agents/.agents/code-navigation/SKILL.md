---
name: nav
description: Choose and use code intelligence tools when tracing symbols, assessing cross-file impact, refactoring, or discovering code structurally.
---

# Code navigation

Use Qartez through MCP for indexed semantic navigation and cross-file analysis.
Use Serena when Qartez cannot answer, its index is stale or incomplete, or
LSP-backed semantics are required. Use `rg` for exact text and ordinary file
edits for small configuration or documentation changes.

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
