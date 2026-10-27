{config, ...}: {
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    casks = ["karabiner-elements"];
    onActivation.cleanup = "none";
  };

  # Clear our old global swap on switch; Karabiner now owns modifier translation.
  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [];
  };
}
