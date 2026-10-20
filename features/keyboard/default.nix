_: {
  den.aspects.keyboard = {
    nixos = {imports = [./_nixos.nix];};
    homeManager = {imports = [./_home.nix];};
  };
}
