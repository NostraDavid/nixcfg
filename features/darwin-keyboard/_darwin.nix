{
  config,
  lib,
  pkgs,
  ...
}: let
  karabiner = pkgs.callPackage ../../pkgs/karabiner-elements-installer {};
  altTab = pkgs.callPackage ../../pkgs/alt-tab-macos {};
in {
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "none";
  };

  environment.systemPackages = [karabiner altTab];

  system.activationScripts.preActivation.text = ''
    PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:$PATH" \
      ${pkgs.bash}/bin/bash ${../../scripts/migrate-darwin-apps.sh} \
        ${lib.escapeShellArg config.system.primaryUser} ${lib.escapeShellArg karabiner.version} \
        ${karabiner}/share/Karabiner-Elements.pkg
  '';

  # Clear our old global swap on switch; Karabiner now owns modifier translation.
  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [];
  };

  launchd.user.agents.alt-tab.serviceConfig = {
    ProgramArguments = ["/usr/bin/open" "-a" "${altTab}/Applications/AltTab.app"];
    RunAtLoad = true;
  };
}
