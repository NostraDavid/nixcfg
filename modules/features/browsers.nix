{config, ...}: {
  flake.modules = {
    nixos.browsers = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.browsers
      ];
    };
    nixos.browsers-extra = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.browsers-extra
      ];
    };
    homeManager.browsers = ../home/browsers.nix;
    homeManager.browsers-extra = {pkgs, ...}: let
      stable = pkgs;
    in {
      home.packages = [
        # Alternative Gemini protocol clients
        stable.amfora # Gemini protocol client (TUI)
        stable.bombadillo # Gemini protocol client (TUI)
        stable.kristall # Gemini protocol client
        stable.lagrange # Gemini protocol client
      ];
    };
  };
}
