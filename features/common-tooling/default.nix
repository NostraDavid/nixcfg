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
        packages = [
          unstable.actionlint # Check GitHub Actions workflows
          unstable.flameshot # Capture and annotate screenshots
          unstable.fast-resume # Find and resume coding agent sessions
          unstable.herdr # Manage coding agents in a terminal
          unstable.hurl # Run and test HTTP requests
          unstable.just # Run project commands from a justfile
          unstable.just-lsp # Language server for justfiles
          unstable.lazyjournal # Browse system, file, and container logs
          unstable.less # Page through terminal output
          unstable.lnav # Browse and analyze logs
          unstable.mise # Manage development tools and environments
          unstable.more # Page through terminal output
          unstable.most # Page through terminal output with color and multiple windows
          unstable.nix-index # Find packages that provide files
          unstable.nix-tree # Explore Nix dependency trees
          unstable.nvd # Compare Nix package versions between generations
          unstable.ov # Page through text with search and table navigation
          unstable.posting # Send HTTP requests from a terminal interface
          unstable.shfmt # Format shell scripts
          unstable.sqruff # Lint and format SQL
          unstable.watchexec # Run commands when files change
          unstable.yazi # Browse files in a terminal
          unstable.zellij # Manage terminal panes and sessions
          unstable.bat-extras.batman # Read man pages with bat syntax highlighting
          local.espeak-ng # Convert text to speech
          (stable.piper-tts.override {
            # Convert text to speech with neural voices
            withAlignment = false;
            withHTTP = false;
            withTrain = false;
          })
        ];
      };
    };
  };
}
