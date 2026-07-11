{config, ...}: {
  flake.modules.nixos.plasma = {main-user, ...}: {
    services = {
      displayManager = {
        autoLogin = {
          enable = true;
          user = main-user;
        };
        sddm.enable = true;
      };
      desktopManager.plasma6.enable = true;
    };
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.plasma
    ];
  };
  flake.modules.homeManager.plasma = ../home/plasma.nix;
}
