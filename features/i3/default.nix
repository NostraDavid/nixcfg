_: {
  den.aspects.i3 = {
    meta.platforms = ["linux"];
    nixos = {imports = [./_nixos.nix];};
    homeManager = {imports = [./_home.nix];};
  };
}
