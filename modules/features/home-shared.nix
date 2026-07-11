{config, ...}: {
  flake.modules.nixos.home-shared = {main-user, ...}: {
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.shared
    ];
  };
  flake.modules.homeManager.shared = ../home/shared.nix;
}
