{
  config,
  inputs,
  lib,
  repoRoot,
  stable,
  unstable,
  ...
}: let
  package = inputs.pi.packages.${stable.stdenv.hostPlatform.system}.coding-agent;
  dot = "${repoRoot}/dotfiles/pi-1.2.0/.pi/agent";
  mk = config.lib.file.mkOutOfStoreSymlink;
in {
  imports = [
    inputs.pi.homeModules.default
  ];

  programs.pi.coding-agent = {
    enable = true;
    inherit package;
    environment.HISTFILE.value = "/dev/null";
  };

  nixcfg.mcp.servers =
    lib.filterAttrs (_: server: server ? url)
    (builtins.fromJSON (builtins.readFile ../../dotfiles/pi-1.2.0/.pi/agent/mcp.json)).mcpServers;

  home = {
    packages = [
      unstable.tmux # pi-term requires tmux for persistent interactive terminals; Zellij is not supported.
    ];
    activation.piConfigBackup = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      if [[ -z "''${HOME_MANAGER_BACKUP_EXT-}" && -z "''${HOME_MANAGER_BACKUP_COMMAND-}" ]]; then
        for file in settings.json mcp.json; do
          if [[ -f "$HOME/.pi/agent/$file" && ! -L "$HOME/.pi/agent/$file" ]]; then
            export HOME_MANAGER_BACKUP_EXT=before-direct-dotfiles
            break
          fi
        done
      fi
    '';

    file = {
      ".pi/agent/settings.json".source = mk "${dot}/settings.json";
      ".pi/agent/mcp.json".source = mk "${dot}/mcp.json";
      ".pi/agent/extensions/workflow".source = mk "${dot}/extensions/workflow";
      ".pi/agent/extensions/subagent".source = "${package}/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/subagent";
      ".pi/agent/agents/scout.md".source = mk "${dot}/agents/scout.md";
      ".pi/agent/agents/planner.md".source = mk "${dot}/agents/planner.md";
      ".pi/agent/agents/reviewer.md".source = mk "${dot}/agents/reviewer.md";
      ".pi/agent/agents/worker.md".source = mk "${dot}/agents/worker.md";
      ".pi/agent/prompts/commit.md".source = mk "${dot}/prompts/commit.md";
      ".pi/agent/prompts/test.md".source = mk "${dot}/prompts/test.md";
      ".pi/agent/prompts/worktree.md".source = mk "${dot}/prompts/worktree.md";
    };
  };
}
