{...}: {
  nix = {
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
