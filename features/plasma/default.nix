_: {
  den.aspects.plasma = {
    meta.platforms = [
      "linux"
    ];
    nixos.imports = [
      ({main-user, ...}: {
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
      })
    ];
    homeManager = {
      imports = [
        ./_home.nix
      ];
    };
  };
}
