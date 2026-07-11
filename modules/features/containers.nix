{config, ...}: {
  flake.modules.nixos.containers = {main-user, ...}: {
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.containers
    ];
  };
  flake.modules.homeManager.containers = ../home/containers.nix;
}
