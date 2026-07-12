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
    homeManager.browsers-extra = {pkgs, ...}: {
      home.packages = with pkgs; [
        # Chrome met flags voor hardware acceleration.
        (google-chrome.override {
          commandLineArgs = [
            "--enable-features=AcceleratedVideoEncoder"
            "--ignore-gpu-blocklist"
            "--enable-zero-copy"
          ];
        })

        # Alternative Gemini protocol clients
        amfora
        bombadillo
        kristall
        lagrange
      ];
    };
  };
}
