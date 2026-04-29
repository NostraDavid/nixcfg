{lib, ...}: {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      max-jobs = lib.mkDefault 2;
      cores = lib.mkDefault 2;
      download-buffer-size = lib.mkDefault 536870912;
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 14d";
      persistent = true;
    };
    optimise = {
      automatic = true;
      persistent = true;
    };
  };
}
