{
  lib,
  linkFarm,
  src,
}: let
  skillNames = builtins.attrNames (lib.filterAttrs (_: enabled: enabled) (import ./skills.nix));
  entries = map (name: let
    path = "${src}/${name}";
  in
    assert lib.assertMsg (builtins.pathExists "${path}/SKILL.md") "Missing polars-skills skill: ${name}"; {
      inherit name path;
    })
  skillNames;
in
  (linkFarm "polars-skills" entries).overrideAttrs (_: {
    passthru = {inherit skillNames;};
    meta.license = lib.licenses.mit;
  })
