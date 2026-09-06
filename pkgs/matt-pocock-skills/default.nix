{
  lib,
  linkFarm,
  src,
}: let
  skillNames = builtins.attrNames (lib.filterAttrs (_: enabled: enabled) (import ./skills.nix));
  entries = map (name: let
    category =
      if builtins.elem name ["grill-me" "grilling" "handoff" "teach" "to-questionnaire" "wait-what" "writing-for-agents"]
      then "productivity"
      else "engineering";
    path = "${src}/skills/${category}/${name}";
  in
    assert lib.assertMsg (builtins.pathExists "${path}/SKILL.md") "Missing matt-pocock-skills skill: ${name}"; {
      inherit name path;
    })
  skillNames;
in
  (linkFarm "matt-pocock-skills" entries).overrideAttrs (_: {
    passthru = {inherit skillNames;};
    meta.license = lib.licenses.mit;
  })
