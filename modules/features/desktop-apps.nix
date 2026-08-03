{config, ...}: {
  flake.modules = {
    nixos.desktop-apps = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.desktop-apps
      ];
    };
    nixos.desktop-apps-extra = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.desktop-apps-extra
      ];
    };
    homeManager.desktop-apps = ../home/desktop-apps.nix;
    homeManager.desktop-apps-extra = {pkgs, ...}: let
      stable = pkgs;
    in {
      home.packages = [
        stable.libreoffice-qt6
        stable.wireguard-ui
      ];
    };
  };
}
