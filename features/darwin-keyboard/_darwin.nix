{
  config,
  lib,
  ...
}: {
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "none";
  };

  assertions = [
    {
      assertion =
        !(lib.any (cask: cask.name == "karabiner-elements") config.homebrew.casks)
        && !(config.services.karabiner-elements.enable or false);
      message = "Loki must not install the Karabiner-Elements privileged daemon.";
    }
  ];

  # Unregister the DriverKit extension while its management tool still exists.
  system.activationScripts.homebrew.text = lib.mkBefore ''
    (
      set -eu
      support='/Library/Application Support/org.pqrs'
      driver="$support/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/deactivate_driver.sh"
      prefix=${lib.escapeShellArg config.homebrew.prefix}
      user=${lib.escapeShellArg config.homebrew.user}
      cask="$prefix/Caskroom/karabiner-elements"
      if [[ -d "$cask" ]]; then
        echo "Uninstalling Karabiner-Elements..." >&2
        if [[ -f "$driver" ]]; then
          /usr/bin/sudo -H -u "$user" /bin/bash "$driver"
        fi
        /usr/bin/sudo -H -u "$user" /usr/bin/env HOMEBREW_NO_AUTOREMOVE=1 "$prefix/bin/brew" uninstall --cask karabiner-elements
      elif [[ -f "$support/Karabiner-Elements/uninstall.sh" ]]; then
        echo "Karabiner-Elements is installed outside Homebrew. Open Karabiner-Elements > Settings > Uninstall to remove it." >&2
      fi
    )
  '';

  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [];
  };
}
