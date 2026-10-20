{
  config,
  inputs,
  repoRoot,
  stable,
  unstable,
  ...
}: let
  package = inputs.pi.packages.${stable.stdenv.hostPlatform.system}.coding-agent;
  dot = "${repoRoot}/dotfiles/pi-1.2.0/.pi/agent";
  mk = config.lib.file.mkOutOfStoreSymlink;
in {
  imports = [inputs.pi.homeModules.default];

  home.packages = [
    unstable.tmux # pi-term requires tmux for persistent interactive terminals; Zellij is not supported.
  ];

  programs.pi.coding-agent = {
    enable = true;
    inherit package;
    settings = builtins.fromJSON (builtins.readFile ../../../dotfiles/pi-1.2.0/.pi/agent/settings.json);
    mcp = builtins.fromJSON (builtins.readFile ../../../dotfiles/pi-1.2.0/.pi/agent/mcp.json);
    environment.HISTFILE.value = "/dev/null";
  };

  home.file = {
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
}
