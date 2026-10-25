# Terminal code navigation

Use `rg` for exact text and candidate references, `fd` for paths, `probe` for
ranked discovery and enclosing syntax, and `ctags` for symbol definitions. Use
`ast-grep` for structural patterns and rewrite previews. Use `cloc` for language
counts, `lizard` for function complexity, and Git for change history.

Use `fzf` to select paths or search results and `sd` to replace text. Use
`semble` for semantic code search on x86_64 Linux.

`features/code-navigation/` in nixcfg contains tools that you invoke directly
from the terminal. Editor extensions and language servers belong to the editor
and development tooling. One shared base supplies these terminal tools on all
six physical hosts. Semble is available only on x86_64 Linux.

These tools run on demand. Scope each invocation to the relevant source paths
and exclude generated dependencies such as `.direnv` and `node_modules`. Text
and syntax matches do not establish symbol identity. Use the project's language
server or compiler when exact references or types are required.

For cross-file investigation, structural edits, or the commands for these tools,
follow `~/.agents/skills/nav/SKILL.md`.
