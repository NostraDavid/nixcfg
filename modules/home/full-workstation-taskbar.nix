{
  config,
  lib,
  ...
}: let
  taskbarLaunchers = [
    "preferred://filemanager"
    "applications:firefox-esr.desktop"
    "applications:code.desktop"
    "applications:com.mitchellh.ghostty.desktop"
    "applications:chatgpt.desktop"
    "applications:io.missioncenter.MissionCenter.desktop"
    "applications:org.keepassxc.KeePassXC.desktop"
    "applications:org.gnome.Evolution.desktop"
    "applications:steam.desktop"
    "applications:signal.desktop"
    "applications:whatpulse.desktop"
    "applications:spotify.desktop"
    "applications:io.github.cboxdoerfer.FSearch.desktop"
    "applications:chromium-browser.desktop"
  ];
  mkBottomPanel = screen: {
    inherit screen;
    location = "bottom";
    widgets = [
      "org.kde.plasma.kickoff"
      "org.kde.plasma.pager"
      {
        iconTasks.launchers = taskbarLaunchers;
      }
      "org.kde.plasma.marginsseparator"
      {
        systemTray = {
          items.extra = [
            "org.kde.plasma.cameraindicator"
            "org.kde.plasma.clipboard"
            "org.kde.plasma.manage-inputmethod"
            "org.kde.plasma.keyboardlayout"
            "org.kde.plasma.devicenotifier"
            "org.kde.plasma.notifications"
            "org.kde.plasma.mediacontroller"
            "org.kde.plasma.brightness"
            "org.kde.plasma.networkmanagement"
            "org.kde.kscreen"
            "org.kde.plasma.keyboardindicator"
            "org.kde.plasma.battery"
            "org.kde.plasma.weather"
            "org.kde.plasma.volume"
          ];
        };
      }
      "org.kde.plasma.digitalclock"
      "org.kde.plasma.showdesktop"
    ];
  };
in {
  options.nixcfg.plasma.taskbarScreens = lib.mkOption {
    type = lib.types.listOf lib.types.ints.unsigned;
    default = [0];
    description = "Screen indices that receive the full-workstation Plasma taskbar.";
  };

  config.programs.plasma.panels =
    map mkBottomPanel config.nixcfg.plasma.taskbarScreens;
}
