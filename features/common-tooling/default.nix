{inputs, ...}: {
  den.aspects.common-tooling = {
    homeManager = {
      stable,
      lib,
      local,
      unstable,
      ...
    }: let
      asdSte100 = stable.callPackage ../../pkgs/asd-ste100-skill {
        src = inputs.asd-ste100-skill;
      };
    in {
      home.file = lib.genAttrs [
        ".agents/skills/asd-ste100"
        ".claude/skills/asd-ste100"
        ".codex/skills/asd-ste100"
        ".config/opencode/skills/asd-ste100"
        ".copilot/skills/asd-ste100"
        ".pi/agent/skills/asd-ste100"
      ] (_: {source = "${asdSte100}/asd-ste100";});
      home.packages = with unstable; [
        actionlint
        flameshot
        hurl
        lnav
        nix-index
        nix-tree
        nvd
        sqruff
        watchexec
        local.espeak-ng
        (stable.piper-tts.override {
          withAlignment = false;
          withHTTP = false;
          withTrain = false;
        })
      ];
    };
  };
}
