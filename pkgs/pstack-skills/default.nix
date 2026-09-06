{
  lib,
  linkFarm,
  src,
}: let
  skillNames = builtins.attrNames (lib.filterAttrs (_: enabled: enabled) (import ./skills.nix));
  entries = map (name: let
    path = "${src}/pstack/skills/${name}";
  in
    assert lib.assertMsg (builtins.pathExists "${path}/SKILL.md") "Missing pstack-skills skill: ${name}"; {
      inherit name path;
    })
  skillNames;
in
  (linkFarm "pstack-skills" entries).overrideAttrs (_: {
    passthru = {inherit skillNames;};
    meta.license = lib.licenses.mit;
  })
