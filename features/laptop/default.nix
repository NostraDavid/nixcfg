_: {
  den.aspects.laptop = {
    meta.platforms = [
      "linux"
    ];
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
