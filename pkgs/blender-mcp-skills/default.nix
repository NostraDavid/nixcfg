{
  applyPatches,
  lib,
  linkFarm,
  src,
}: let
  patchedSrc = applyPatches {
    name = "blender-mcp-skills-source";
    inherit src;
    patches = [./official-server.patch];
  };
  skillNames = builtins.attrNames (lib.filterAttrs (_: enabled: enabled) (import ./skills.nix));
  entries = map (name: let
    path = "${patchedSrc}/skill/${name}";
  in
    assert lib.assertMsg (builtins.pathExists "${src}/skill/${name}/SKILL.md") "Missing blender-mcp-skills skill: ${name}"; {
      inherit name path;
    })
  skillNames;
in
  (linkFarm "blender-mcp-skills" (entries
    ++ [
      {
        name = "LICENSE";
        path = "${src}/LICENSE";
      }
    ])).overrideAttrs (_: {
    version = "unstable-2026-07-12";
    passthru = {inherit skillNames;};
    meta.license = lib.licenses.mit;
  })
