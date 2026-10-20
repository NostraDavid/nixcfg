_: {
  den.aspects.location = {
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
