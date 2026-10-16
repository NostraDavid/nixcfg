{
  config,
  inputs,
  repoRoot,
  stable,
  ...
}: let
  package = inputs.pi.packages.${stable.stdenv.hostPlatform.system}.coding-agent;
  dot = "${repoRoot}/dotfiles/pi-1.2.0/.pi/agent";
  mk = config.lib.file.mkOutOfStoreSymlink;
in {
  imports = [inputs.pi.homeModules.default];

  programs.pi.coding-agent = {
    enable = true;
    inherit package;
    settings = builtins.fromJSON (builtins.readFile ../../../dotfiles/pi-1.2.0/.pi/agent/settings.json);
    environment.HISTFILE.value = "/dev/null";
  };

  home.file = {
    ".pi/agent/extensions/workflow".source = mk "${dot}/extensions/workflow";
    ".pi/agent/prompts/commit.md".source = mk "${dot}/prompts/commit.md";
    ".pi/agent/prompts/test.md".source = mk "${dot}/prompts/test.md";
  };
}
