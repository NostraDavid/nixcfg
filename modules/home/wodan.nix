# Home-manager programs specific to wodan.
{
  pkgs,
  inputs,
  lib,
  ...
}: let
  codexDesktopSafe = let
    codexDesktop = inputs.codex-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.codex-desktop;
  in
    pkgs.symlinkJoin {
      name = "codex-desktop-safe-${codexDesktop.version}";
      paths = [codexDesktop];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram "$out/bin/codex-desktop" \
          --run 'volatile_dir="/tmp/$USER-codex"; ${pkgs.coreutils}/bin/install -d -m 700 "$volatile_dir"' \
          --set-default CODEX_ELECTRON_DISABLE_GPU_COMPOSITING 1
      '';
    };
  taskbarLaunchers = [
    "preferred://filemanager"
    "applications:firefox-esr.desktop"
    "applications:code.desktop"
    "applications:org.wezfurlong.wezterm.desktop"
    "applications:io.missioncenter.MissionCenter.desktop"
    "applications:org.keepassxc.KeePassXC.desktop"
    "applications:org.gnome.Evolution.desktop"
    "applications:steam.desktop"
    "applications:signal.desktop"
    "applications:whatpulse.desktop"
    "applications:spotify.desktop"
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
  programs = {
    plasma = {
      configFile = {
        kcminputrc = {
          "Libinput/1133/49970/Logitech Gaming Mouse G502".PointerAccelerationProfile = 1;
          Mouse = {
            X11LibInputXAccelProfileFlat = true;
            cursorSize = 36;
            cursorTheme = "breeze_cursors";
          };
        };

        ktrashrc."\\/home\\/david\\/.local\\/share\\/Trash" = {
          Days = 7;
          LimitReachedAction = 0;
          Percent = 10;
          UseSizeLimit = true;
          UseTimeLimit = false;
        };

        kwinrc = {
          Desktops = {
            Number = 1;
            Rows = 1;
          };
          NightColor.Active = true;
          TabBox = {
            ActivitiesMode = 0;
            DesktopMode = 0;
            HighlightWindows = false;
            MultiScreenMode = 1;
            OrderMinimizedMode = 1;
          };
          Tiling.padding = 4;
          Xwayland.Scale = 1.25;
          "org.kde.kdecoration2".theme = "__aurorae__svg__WillowDarkBlur";
        };
      };

      panels = [
        {
          screen = 1;
          location = "top";
          height = 26;
          widgets = [
            "org.kde.plasma.appmenu"
          ];
        }
        (mkBottomPanel 0)
        (mkBottomPanel 1)
      ];
    };

    codexDesktopLinux = {
      enable = true;
      package = codexDesktopSafe;
    };

    direnv = {
      enable = true;
      config.global = {
        hide_env_diff = true;
        disable_stdin = true;
        warn_timeout = "15s";
      };
      nix-direnv.enable = true;
    };
  };

  xdg = {
    configFile = {
      "autostart/io.github.martinrotter.rssguard.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=RSS Guard
        Comment=Simple, yet powerful news feed reader
        Icon=io.github.martinrotter.rssguard
        Exec=${pkgs.rssguard}/bin/rssguard
        Categories=Feed;News;Network;Qt;
        StartupWMClass=rssguard
        X-GNOME-SingleWindow=true
        X-GNOME-Autostart-Delay=15
        X-LXQt-Need-Tray=true
      '';

      "codex-desktop/settings.json".text = builtins.toJSON {
        codex-linux-prompt-window-enabled = false;
        codex-linux-system-tray-enabled = false;
        codex-linux-warm-start-enabled = true;
      };
    };
  };

  home.activation.codexVolatileLogs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    codex_dir="$HOME/.codex"
    volatile_dir="/tmp/$USER-codex"

    $DRY_RUN_CMD mkdir -p "$codex_dir" "$volatile_dir"
    $DRY_RUN_CMD chmod 700 "$volatile_dir"

    for name in logs_2.sqlite logs_2.sqlite-shm logs_2.sqlite-wal; do
      link="$codex_dir/$name"
      target="$volatile_dir/$name"

      if [ -L "$link" ] && [ "$(${pkgs.coreutils}/bin/readlink "$link")" != "$target" ]; then
        $DRY_RUN_CMD rm -f "$link"
      fi

      if [ -e "$link" ] && [ ! -L "$link" ]; then
        $DRY_RUN_CMD rm -f "$link"
      fi

      if [ ! -L "$link" ]; then
        $DRY_RUN_CMD ln -s "$target" "$link"
      fi
    done
  '';

  systemd.user.services.ydotoold = {
    Unit = {
      Description = "ydotool input injection daemon";
    };
    Service = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
