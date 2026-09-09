{
  applyPatches,
  lib,
  linkFarm,
  src,
}: let
  patchedSrc = applyPatches {
    name = "cc-blender-skills-source";
    inherit src;
    patches = [./official-server.patch ./summary-semantics.patch ./export-scene-isolation.patch];
    postPatch = ''
      while IFS= read -r -d "" file; do
        sed -i \
          -e '/^allowed-tools:/d' \
          -e 's/mcp__blender__//g' \
          -e 's/get_scene_info/get_objects_summary/g' \
          -e 's/get_object_info/get_object_detail_summary/g' \
          -e 's/get_viewport_screenshot/get_screenshot_of_area_as_image/g' \
          "$file"
      done < <(find plugin/skills -type f -name '*.md' -print0)

      while IFS= read -r -d "" file; do
        printf '\n' >> "$file"
        cat ${./server-conventions.md} >> "$file"
      done < <(find plugin/skills -name SKILL.md -print0)
    '';
  };
  skillNames = builtins.attrNames (lib.filterAttrs (_: enabled: enabled) (import ./skills.nix));
  entries = map (name: let
    path = "${patchedSrc}/plugin/skills/${name}";
  in
    assert lib.assertMsg (builtins.pathExists "${src}/plugin/skills/${name}/SKILL.md") "Missing cc-blender-skills skill: ${name}"; {
      inherit name path;
    })
  skillNames;
in
  (linkFarm "cc-blender-skills" (entries
    ++ [
      {
        name = "LICENSE";
        path = "${src}/LICENSE";
      }
    ])).overrideAttrs (_: {
    inherit (builtins.fromJSON (builtins.readFile "${src}/plugin/manifest.json")) version;
    passthru = {inherit skillNames;};
    meta.license = lib.licenses.mit;
  })
