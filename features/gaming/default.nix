_: {
  den.aspects.gaming = {
    nixos = {imports = [./_nixos.nix];};
    homeManager = {imports = [./_home.nix];};
  };
}
