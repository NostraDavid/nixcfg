_: {
  den.aspects.workstation-runtime = {
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
