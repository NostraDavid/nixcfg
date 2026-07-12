{config, ...}: {
  flake.modules = {
    nixos = {
      development = {main-user, ...}: {
        home-manager.users.${main-user}.imports = [
          config.flake.modules.homeManager.development
        ];
      };
      development-core = {main-user, ...}: {
        home-manager.users.${main-user}.imports = [
          config.flake.modules.homeManager.development-core
        ];
      };
      development-extra = {main-user, ...}: {
        home-manager.users.${main-user}.imports = [
          config.flake.modules.homeManager.development-extra
        ];
      };
    };
    homeManager = {
      development = {
        imports = [
          config.flake.modules.homeManager.development-core
          config.flake.modules.homeManager.development-mantle
        ];
      };
      development-core = ../home/development-core.nix;
      development-mantle = ../home/development-mantle.nix;
      development-extra = ../home/development-extra.nix;
    };
  };
}
