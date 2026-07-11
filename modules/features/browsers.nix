{config, ...}: {
  flake.modules = {
    nixos.browsers = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.browsers
      ];
    };
    homeManager.browsers = ../home/browsers.nix;
    homeManager.browsers-wodan = ../home/wodan-browsers.nix;
  };
}
