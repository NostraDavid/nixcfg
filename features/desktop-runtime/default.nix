_: {
  den.aspects.desktop-runtime = {
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
