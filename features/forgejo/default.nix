_: {
  den.aspects.forgejo = {
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
