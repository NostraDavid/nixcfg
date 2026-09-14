{
  applyPatches,
  lib,
  linkFarm,
  src,
}: let
  patchedSrc = applyPatches {
    name = "blender-reference-skills-source";
    inherit src;
    patches = [./remove-external-validator.patch];
  };
  skillNames = builtins.attrNames (lib.filterAttrs (_: enabled: enabled) (import ./skills.nix));
  entries = map (name:
    assert lib.assertMsg (builtins.pathExists "${src}/SKILL.md") "Missing blender-reference-skills router"; {
      inherit name;
      path = patchedSrc;
    })
  skillNames;
in
  (linkFarm "blender-reference-skills" entries).overrideAttrs (_: {
    version = "unstable-${src.lastModifiedDate}-${src.shortRev}";
    passthru = {inherit skillNames;};
    meta.license = lib.licenses.agpl3Only;
  })
