_: {
  den.aspects.plasma = {
    meta.platforms = [
      "linux"
    ];
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
    homeManager = {
      imports = [
        ./_home.nix
      ];
    };
  };
}
