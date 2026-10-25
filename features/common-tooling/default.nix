_: {
  den.aspects.common-tooling = {
    homeManager = {
      config,
      stable,
      lib,
      local,
      unstable,
      ...
    }: let
      asdSte100 = stable.callPackage ../../pkgs/asd-ste100-skill {};
    in {
      home = {
        activation = {
          linkPackageCommands = lib.hm.dag.entryAfter ["installPackages" "linkGeneration"] ''
            $DRY_RUN_CMD ${stable.bash}/bin/bash ${./link-package-commands.sh} \
              ${lib.escapeShellArg config.home.profileDirectory} \
              ${lib.escapeShellArg "${config.home.homeDirectory}/.local/bin"}
          '';
        };
        file = lib.genAttrs [
          ".agents/skills/asd-ste100"
          ".claude/skills/asd-ste100"
          ".codex/skills/asd-ste100"
          ".config/opencode/skills/asd-ste100"
          ".copilot/skills/asd-ste100"
          ".pi/agent/skills/asd-ste100"
        ] (_: {source = "${asdSte100}/asd-ste100";});
        packages = with unstable; [
          actionlint
          flameshot
          fast-resume
          herdr
          hurl
          just
          just-lsp
          lazyjournal
          lnav
          mise
          nix-index
          nix-tree
          nvd
          ov
          posting
          shfmt
          sqruff
          watchexec
          yazi
          zellij
          local.espeak-ng
          (stable.piper-tts.override {
            withAlignment = false;
            withHTTP = false;
            withTrain = false;
          })
        ];
      };
    };
  };
}
