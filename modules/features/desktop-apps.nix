{config, ...}: {
  flake.modules = {
    nixos.desktop-apps = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.desktop-apps
      ];
    };
    homeManager.desktop-apps = ../home/desktop-apps.nix;
    homeManager.desktop-apps-wodan = {
      imports = [
        ../home/wodan-desktop-apps.nix
        ../home/wodan-graphics-libs.nix
      ];
    };
  };
}
