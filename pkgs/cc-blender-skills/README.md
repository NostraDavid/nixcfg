# CC Blender skills

Imports the 30 skills under `plugin/skills` from
<https://github.com/RobLe3/cc-blender-skill>, pinned by the `cc-blender-skills`
flake input. Each skill has an enable switch in `skills.nix` and is linked into
Codex, Copilot, and OpenCode with the other shared skills. Assets, scripts, and
references stay alongside their skills. The MIT license is included.

The package adapts the community-server instructions to the official Blender Lab
server already configured here. During the build it removes Claude-specific
`allowed-tools` declarations and the `mcp__blender__` prefix, maps scene/object/
screenshot tool names, and appends the shared `server-conventions.md` to each
skill. The client still supplies its own MCP namespace when calling a tool.

`official-server.patch` corrects setup guidance and replaces unavailable asset
download/generation tools with a user-provided local asset workflow. It also
limits world resets to requests that authorize replacing the world setup.

This installs skills, not the upstream MCP configuration or a new Blender addon.
Bundled Python helpers retain their upstream dependency requirements; the skill
package does not install a separate Python environment for them.

Verify with `nix build path:.#cc-blender-skills --no-link`, inspect the
generated skill text against the connected tools, and evaluate wodan before
switching.

Verified against the 26 connected official Blender Lab tools and installed
server source on 2026-09-10:

| Upstream tool, without client prefix | Official tool                     | Difference                                                                   |
| ------------------------------------ | --------------------------------- | ---------------------------------------------------------------------------- |
| `execute_blender_code`               | `execute_blender_code`            | Return a dict through `result`.                                              |
| `get_scene_info`                     | `get_objects_summary`             | Collection tree; no geometry counts.                                         |
| `get_object_info`                    | `get_object_detail_summary`       | `name` parameter; dimensions but no triangle counts or bounding-box corners. |
| `get_viewport_screenshot`            | `get_screenshot_of_area_as_image` | Requires `area_ui_type="VIEW_3D"`.                                           |
| `download_polyhaven_asset`           | None                              | No asset-service integration.                                                |
| `download_sketchfab_model`           | None                              | No asset-service integration.                                                |
| `generate_hyper3d_model_via_text`    | None                              | No model-generation integration.                                             |

`summary-semantics.patch` corrects instructions that assumed scene/object
summaries include mesh statistics. Use Python execution on the evaluated mesh
for those measurements. A live connection check failed because Blender was not
listening during that comparison. A subsequent live test on Blender 5.2.1 passed
scene/object inspection, Cycles rendering, screenshots, keyframe sampling, and
GLB export/import through a background Blender process.

That test found that selection-only export also includes selected objects from
other scenes. `export-scene-isolation.patch` adds `use_active_scene=True`
alongside `use_selection=True`. The corrected export contained one intended
mesh, 300 triangles, its material, and its animation; the original scene was
preserved.
