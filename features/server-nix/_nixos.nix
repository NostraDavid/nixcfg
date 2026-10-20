{lib, ...}: {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      max-jobs = lib.mkDefault 2;
      cores = lib.mkDefault 2;
      download-buffer-size = lib.mkDefault 67108864;
      keep-derivations = lib.mkForce false;
      keep-outputs = lib.mkForce false;
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
