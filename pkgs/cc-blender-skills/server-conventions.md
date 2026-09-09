## Installed server conventions

This installation uses the official Blender Lab MCP server. Tool names in this
skill are server-local names. Select the matching tool exposed by your client,
which may add a prefix such as `mcp__blender__`. Follow that tool's actual
schema; for example, object details use `name` and viewport screenshots use
`area_ui_type="VIEW_3D"`. Code execution returns a JSON-serializable dict
assigned to `result`; use a dedicated tool when it covers the action.

For a GLB export of selected objects in the current scene, set both
`use_selection=True` and `use_active_scene=True`. Selection alone also includes
selected objects from other scenes. Inspect the exported node and scene lists.

`get_objects_summary` returns a collection tree. Traverse its children and
deduplicate objects by name when counting, because objects can belong to
multiple collections. `get_object_detail_summary` returns transforms,
dimensions, modifiers, and materials, but no vertex counts, triangle counts, or
bounding-box corners. For those measurements, use `execute_blender_code` to
inspect the evaluated mesh. Call `mesh.calc_loop_triangles()` before counting
`mesh.loop_triangles`, and release the temporary mesh with `to_mesh_clear()`.
Transform bounding-box corners with `matrix_world` for world-space comparisons.

The official server has no Poly Haven, Sketchfab, or Hyper3D download/generation
tool. Python execution can import an existing asset, but is not an equivalent
asset search or generation service.

Resolve reference and script paths relative to this skill's directory and
sibling skills. Bundled scripts may require additional Python dependencies. The
installed skill files are read-only Nix store artifacts; maintain adaptations in
nixcfg's `pkgs/cc-blender-skills` package when the user requests skill changes.
