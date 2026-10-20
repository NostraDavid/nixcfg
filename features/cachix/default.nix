_: {
  den.aspects.cachix = {
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
