# Serena

Use Serena through MCP for symbol-aware code navigation and editing when
language semantics or cross-file relationships matter.

Serena is the fallback behind Qartez. Use it when Qartez cannot answer a query,
its index is stale or incomplete, or LSP-backed language semantics are required.
Do not repeat successful Qartez queries in Serena merely for confirmation.

Prefer Serena for:

- symbol overviews and locating definitions;
- finding references, implementations, and callers;
- cross-file symbol renames and refactors;
- replacing a complete symbol body; and
- inserting code relative to an existing symbol.

Use `rg` for exact text, Probe for zero-index structural or ranked discovery,
and ordinary file edits for small configuration or documentation changes. Do not
use Serena's memory subsystem when Engram is the configured canonical memory.

Inspect the target symbol and its references before a semantic edit. After an
edit, inspect diagnostics and run tests or checks proportionate to the change.
Fall back to text editing when the language server is unavailable or the file
type has no useful symbol model.

Do not run `serena init`, `serena setup`, install hooks, change the language
backend, or write client configuration unless the user explicitly asks for
Serena configuration.
