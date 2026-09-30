# Home-manager programs specific to wodan.
{
  inputs,
  lib,
  local,
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
      kwin.effects.zoom = {
        enable = true;
        mousePointer = "scale";
        mouseTracking = "proportional";
        # Four steps reach exactly 2x linear zoom: one source quarter fills the screen.
        zoomFactor = 1.189207115002721;
      };

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
  };

  xdg = {
    configFile = {
      "codex-desktop/settings.json".text = builtins.toJSON {
        codex-linux-prompt-window-enabled = false;
        codex-linux-system-tray-enabled = false;
        codex-linux-warm-start-enabled = true;
      };
    };
  };

  home = {
    packages = [local.unsloth];
    activation = {
      codexVolatileLogs = lib.hm.dag.entryAfter ["writeBoundary"] ''
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

      codexBrowserRuntime = lib.hm.dag.entryAfter ["agentMemoryClients" "blenderMcpClient" "linkGeneration"] ''
        for plugin in browser chrome; do
          cache="$HOME/.codex/plugins/cache/openai-bundled/$plugin/${local.chatgpt.version}"
          if [ -L "$cache" ]; then
            $DRY_RUN_CMD rm "$cache"
          fi
          if [ ! -f "$cache/scripts/browser-service.mjs" ] || [ ! -f "$cache/scripts/browser-client.mjs" ]; then
            $DRY_RUN_CMD mkdir -p "$cache"
            $DRY_RUN_CMD cp -R --no-preserve=mode,ownership \
              "${local.chatgpt}/lib/chatgpt/resources/plugins/openai-bundled/plugins/$plugin/." "$cache/"
          fi
          $DRY_RUN_CMD ${stable.findutils}/bin/find "$cache" -type d -exec ${stable.coreutils}/bin/chmod u+w '{}' +
        done

        # The Browser service must resolve inside CODEX_HOME's trusted code path.
        $DRY_RUN_CMD sed -i -E \
          -e 's#/nix/store/[a-z0-9]+-chatgpt-[0-9.]+/lib/chatgpt/resources#${local.chatgpt}/lib/chatgpt/resources#g' \
          -e 's#(BROWSER_USE_CODEX_APP_VERSION = ")[^"]+#\1${local.chatgpt.version}#' \
          -e 's#/nix/store/[a-z0-9]+-chatgpt-[0-9.]+/lib/chatgpt/resources/plugins/openai-bundled/plugins/browser/scripts/browser-service.mjs#/home/david/.codex/plugins/cache/openai-bundled/browser/${local.chatgpt.version}/scripts/browser-service.mjs#g' \
          -e 's#(/home/[^/]+/[.]codex/plugins/cache/openai-bundled/browser/)[0-9.]+(/scripts/browser-service.mjs)#\1${local.chatgpt.version}\2#g' \
          "$HOME/.codex/config.toml"
      '';
    };
  };

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
