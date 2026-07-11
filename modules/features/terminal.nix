{config, ...}: {
  flake.modules.nixos.terminal = {main-user, ...}: {
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.terminal
    ];
  };
  flake.modules.homeManager.terminal = ../home/terminal.nix;
}
