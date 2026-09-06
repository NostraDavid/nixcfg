{
  lib,
  linkFarm,
  src,
}: let
  skillNames = builtins.attrNames (lib.filterAttrs (_: enabled: enabled) (import ./skills.nix));
  entries = map (name: let
    path = "${src}/skills/${name}";
  in
    assert lib.assertMsg (builtins.pathExists "${path}/SKILL.md") "Missing awesome-copilot-skills skill: ${name}"; {
      inherit name path;
    })
  skillNames;
in
  (linkFarm "awesome-copilot-skills" entries).overrideAttrs (_: {
    passthru = {inherit skillNames;};
    meta.license = lib.licenses.mit;
  })
