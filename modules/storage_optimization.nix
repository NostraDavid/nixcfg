{...}: {
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 31d";
      persistent = true;
    };
    optimise = {
      automatic = true;
      persistent = true;
    };
  };
}
