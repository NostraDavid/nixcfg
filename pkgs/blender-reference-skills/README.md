# Blender reference skills

Imports <https://github.com/LevyBytes/AI-SKILL-blender> through the locked
`blender-reference-skills` input. `skills.nix` enables the `blender` router for
Codex, Copilot, and OpenCode through the shared skill links.

The complete source tree is retained, including its AGPL-3.0 license, six nested
subskills, reference indexes, topic metadata, and reference files. Keeping the
subskills under `blender` preserves the router's relative paths and avoids
publishing generic names such as `python-api` as separate top-level skills.

`remove-external-validator.patch` removes verification commands from the seven
skill files. Those commands require an external `skill-drafting` repository and
the author's Windows `DEVROOT` layout. The documentation remains unchanged.

This package complements `blender-mcp-skills`: `blender` supplies reference
material, while `blender-mcp` describes operating the configured Blender server.
Verify version-sensitive facts against the installed Blender version.

Build with `nix build path:.#blender-reference-skills --no-link` and evaluate
wodan before activating with `just switch`.
