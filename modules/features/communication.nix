{config, ...}: {
  flake.modules = {
    nixos.communication = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.communication
      ];
    };
    nixos.work-communication = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.work-communication
      ];
    };
    homeManager.communication = ../home/communication.nix;
    homeManager.work-communication = {stable, ...}: {
      home.packages = [
        stable.slack # Work chat; intentionally excluded from lean workstations
      ];
    };
  };
}
