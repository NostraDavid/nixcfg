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
    homeManager.desktop-apps-extra = {pkgs, ...}: {
      home.packages = with pkgs; [
        libreoffice-qt6
        wireguard-ui
      ];
    };
  };
}
