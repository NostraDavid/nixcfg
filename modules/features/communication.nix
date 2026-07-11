{config, ...}: {
  flake.modules = {
    nixos.communication = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.communication
      ];
    };
    homeManager.communication = ../home/communication.nix;
    homeManager.communication-wodan = ../home/wodan-communication.nix;
  };
}
