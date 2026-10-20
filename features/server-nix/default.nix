_: {
  den.aspects.server-nix = {
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
