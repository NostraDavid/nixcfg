_: {
  den.aspects.hyprland = {
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
