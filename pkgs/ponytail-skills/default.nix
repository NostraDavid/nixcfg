{
  lib,
  linkFarm,
  src,
}: let
  skillNames = builtins.attrNames (lib.filterAttrs (_: enabled: enabled) (import ./skills.nix));
  entries = map (name: let
    path = "${src}/skills/${name}";
  in
    assert lib.assertMsg (builtins.pathExists "${path}/SKILL.md") "Missing ponytail-skills skill: ${name}"; {
      inherit name path;
    })
  skillNames;
in
  (linkFarm "ponytail-skills" entries).overrideAttrs (_: {
    version = "4.9.0";
    passthru = {inherit skillNames;};
    meta.license = lib.licenses.mit;
  })
