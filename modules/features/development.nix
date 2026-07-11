{config, ...}: {
  flake.modules = {
    nixos.development = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.development
      ];
    };
    homeManager.development = ../home/development.nix;
    homeManager.development-wodan = ../home/wodan-tools.nix;
  };
}
