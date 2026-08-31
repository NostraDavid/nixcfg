# Home-manager programs specific to wodan.
{
  inputs,
  lib,
  stable,
  ...
}: let
  inline = {
    codexDesktopSafe = let
      codexDesktop = inputs.codex-desktop-linux.packages.${stable.stdenv.hostPlatform.system}.codex-desktop;
    in
      stable.symlinkJoin {
        name = "codex-desktop-safe-${codexDesktop.version}";
        paths = [codexDesktop];
        nativeBuildInputs = [stable.makeWrapper];
        postBuild = ''
          wrapProgram "$out/bin/codex-desktop" \
            --run 'volatile_dir="/tmp/$USER-codex"; ${stable.coreutils}/bin/install -d -m 700 "$volatile_dir"' \
            --set-default CODEX_ELECTRON_DISABLE_GPU_COMPOSITING 1
        '';
      };
  };
in {
  nixcfg.plasma.taskbarScreens = [0 1];

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
    };

    codexDesktopLinux = {
      enable = true;
      package = inline.codexDesktopSafe;
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
        Exec=${stable.rssguard}/bin/rssguard
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

      if [ -L "$link" ] && [ "$(${stable.coreutils}/bin/readlink "$link")" != "$target" ]; then
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
      ExecStart = "${stable.ydotool}/bin/ydotoold";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
