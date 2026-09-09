# Blender MCP skill

Imports `skill/blender-mcp` from <https://github.com/vinhelysia/blender-mcp>,
pinned through the `blender-mcp-skills` flake input. `skills.nix` enables it for
the shared Codex, Copilot, and OpenCode skill links in
`modules/home/dotfiles.nix`. The MIT license is included in the package output.

Only the skill is installed. The existing official Blender Lab MCP server and
extension remain configured by `modules/home/media/blender-mcp.nix`.

`official-server.patch` adapts the upstream skill to that server:

- Uses the official tool names and `result` for both interactive and CLI code.
- Removes unsupported per-call timeout and binary auto-detection instructions.
- Prefers dedicated tools when available.
- Replaces the author's Godot project defaults and Windows export directory with
  project-specific export guidance.
- Limits automatic activation to Blender work.

When updating the input, review the patch against the connected server's tool
schemas, then build `path:.#blender-mcp-skills` and evaluate wodan before
switching. The MCP connection is currently configured for Codex; other clients
need an equivalent connection to use the skill's tools.
