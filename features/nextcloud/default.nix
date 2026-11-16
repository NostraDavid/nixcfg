_: {
  den.aspects.nextcloud = {
    meta.platforms = ["linux"];
    nixos.imports = [./_nixos.nix];
  };
}
