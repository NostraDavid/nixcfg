{fixtureHome}: let
  flake = builtins.getFlake (toString ../.);
  pkgs = flake.legacyPackages.x86_64-linux;
  fixture = flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = {
      stable = pkgs;
      repoRoot = toString ../.;
    };
    modules = [
      ../features/terminal/_locate.nix
      {
        home = {
          username = "fixture";
          homeDirectory = fixtureHome;
          stateVersion = "25.11";
        };
        xdg.cacheHome = "${fixtureHome}/cache with spaces";
      }
    ];
  };
in {
  commands = fixture.config.home.path;
}
