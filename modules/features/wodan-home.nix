{config, ...}: {
  flake.modules.nixos.wodan-home = {main-user, ...}: {
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.wodan
    ];
  };
  flake.modules.homeManager.wodan = ../home/wodan.nix;
}
