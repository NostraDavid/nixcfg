_: {
  den.aspects.common-tooling = {
    homeManager = {
      stable,
      lib,
      local,
      unstable,
      ...
    }: {
      home.file = lib.genAttrs [
        ".agents/skills/asd-ste100"
        ".claude/skills/asd-ste100"
        ".codex/skills/asd-ste100"
        ".config/opencode/skills/asd-ste100"
        ".copilot/skills/asd-ste100"
        ".pi/agent/skills/asd-ste100"
      ] (_: {source = "${local.asd-ste100-skill}/asd-ste100";});
      home.packages = with unstable; [
        actionlint
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
