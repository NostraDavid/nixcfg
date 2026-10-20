_: {
  den.aspects.darwin-keyboard = {
    darwin = {imports = [./_darwin.nix];};
    homeManager = {imports = [./_home.nix];};
  };
}
