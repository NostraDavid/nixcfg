{config, ...}: {
  # Karabiner 16+ needs the signed upstream installer and its DriverKit setup.
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    casks = ["karabiner-elements" "alt-tab"];
    onActivation.cleanup = "none";
  };

  # Clear our old global swap on switch; Karabiner now owns modifier translation.
  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [];
  };

  launchd.user.agents.alt-tab.serviceConfig = {
    ProgramArguments = ["/usr/bin/open" "-a" "/Applications/AltTab.app"];
    RunAtLoad = true;
  };
}
