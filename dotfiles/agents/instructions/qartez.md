# Qartez

Use Qartez through MCP for indexed, graph-aware code navigation and editing when
language semantics or cross-file relationships matter.

Treat Qartez as the primary code-intelligence tool. Fall back to Serena when
Qartez cannot answer a query, its index is stale or incomplete, or LSP-backed
language semantics are required. Do not duplicate successful Qartez queries in
Serena merely for confirmation.

Start with `qartez_map` for an unfamiliar repository. Prefer `qartez_find`,
`qartez_outline`, and `qartez_read` for symbol discovery and targeted reads.
Call `qartez_impact` before editing an important file. Enable the analysis tier
with `qartez_tools` when references, call graphs, co-change data, or hotspot
analysis are needed.

Use `rg` for exact text, Probe for zero-index structural or ranked discovery,
and ordinary file edits for small configuration or documentation changes.

Preview Qartez refactoring operations before applying them. After an edit,
inspect the affected files and run tests or checks proportionate to the change.
Do not run `qartez-setup`, install hooks, or write client configuration unless
the user explicitly asks for Qartez configuration.
