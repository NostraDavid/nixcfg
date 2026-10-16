{config, ...}: {
  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [
      {
        HIDKeyboardModifierMappingSrc = 30064771296; # Left Control
        HIDKeyboardModifierMappingDst = 30064771299; # Left Command
      }
      {
        HIDKeyboardModifierMappingSrc = 30064771299; # Left Command
        HIDKeyboardModifierMappingDst = 30064771296; # Left Control
      }
      {
        HIDKeyboardModifierMappingSrc = 30064771300; # Right Control
        HIDKeyboardModifierMappingDst = 30064771303; # Right Command
      }
      {
        HIDKeyboardModifierMappingSrc = 30064771303; # Right Command
        HIDKeyboardModifierMappingDst = 30064771300; # Right Control
      }
    ];
  };

  # macOS clears hidutil mappings at reboot, so restore them at login too.
  launchd.user.agents.keyboard-mapping.serviceConfig = {
    ProgramArguments = [
      "/usr/bin/hidutil"
      "property"
      "--set"
      (builtins.toJSON {UserKeyMapping = config.system.keyboard.userKeyMapping;})
    ];
    RunAtLoad = true;
  };
}
