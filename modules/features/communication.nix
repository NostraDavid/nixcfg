{config, ...}: {
  flake.modules = {
    nixos.communication = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.communication
      ];
    };
    nixos.communication-extra = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.communication-extra
      ];
    };
    homeManager.communication = ../home/communication.nix;
    homeManager.communication-extra = {pkgs, ...}: {
      home.packages = with pkgs; [
        slack
      ];
    };
  };
}
