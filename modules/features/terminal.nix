{config, ...}: {
  flake.modules.nixos.terminal = {main-user, ...}: {
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.terminal
    ];
  };
  flake.modules.homeManager.terminal = {
    imports = [
      ../home/terminal.nix
      ../home/terminal-packages.nix
    ];
  };
}
