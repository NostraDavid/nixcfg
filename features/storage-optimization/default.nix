_: {
  den.aspects.storage-optimization = {
    nixos.imports = [
      {
        nix = {
          settings = {
            max-jobs = 24;
          };
          gc = {
            automatic = true;
            dates = "daily";
            options = "--delete-older-than 31d";
            persistent = true;
          };
          optimise = {
            automatic = true;
            persistent = true;
          };
        };
      }
    ];
  };
}
