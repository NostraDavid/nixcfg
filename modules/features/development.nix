{config, ...}: {
  flake.modules = {
    nixos.development = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.development
      ];
    };
    nixos.development-extra = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.development-extra
      ];
    };
    homeManager.development = ../home/development.nix;
    homeManager.development-extra = ../home/development-extra.nix;
  };
}
