{
  lib,
  stable,
  unstable,
  ...
}: let
  skill =
    stable.runCommand "worktrunk-skill" {
      nativeBuildInputs = [(stable.python3.withPackages (ps: [ps.pyyaml]))];
    } ''
      cp -R ${unstable.worktrunk}/share/skills/worktrunk/worktrunk "$out"
      chmod -R u+w "$out"
      python ${./skill-descriptions.py} ${../../dotfiles/agents/descriptions.json} "$out"
    '';
in {
  home.packages = [unstable.worktrunk];
  home.file = lib.genAttrs [
    ".agents/skills/worktrunk"
    ".codex/skills/worktrunk"
    ".copilot/skills/worktrunk"
    ".config/opencode/skills/worktrunk"
    ".pi/agent/skills/worktrunk"
  ] (_: {source = skill;});
}
