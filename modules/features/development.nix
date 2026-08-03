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
      development-lab = {main-user, ...}: {
        home-manager.users.${main-user}.imports = [
          config.flake.modules.homeManager.development-lab
          config.flake.modules.homeManager.gamedev-forge
        ];
      };
      gamedev-forge = {main-user, ...}: {
        home-manager.users.${main-user}.imports = [
          config.flake.modules.homeManager.gamedev-forge
        ];
      };
    };
    homeManager = {
      development = {
        imports = [
          config.flake.modules.homeManager.development-core
          config.flake.modules.homeManager.development-mantle
          ../home/development-security.nix
          ../home/development-tooling.nix
        ];
      };
      development-core = ../home/development-core.nix;
      development-mantle = ../home/development-mantle.nix;
      development-lab = ../home/development-lab.nix;
      gamedev-forge = ../home/gamedev-forge.nix;
    };
  };
}
