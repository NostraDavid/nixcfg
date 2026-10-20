_: {
  den.aspects.nvidia-workstation = {
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
