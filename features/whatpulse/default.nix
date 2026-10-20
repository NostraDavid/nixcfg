_: {
  den.aspects.whatpulse = {
    nixos = {imports = [./_nixos.nix];};
    homeManager = {imports = [./_home.nix];};
  };
}
