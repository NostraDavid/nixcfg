_: {
  den.aspects = {
    media = {
      homeManager = {imports = [./_apps.nix ./_tools.nix];};
    };
    media-production = {
      homeManager = {imports = [./_production.nix];};
    };
  };
}
