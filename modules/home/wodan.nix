# Home-manager programs specific to wodan.
{
  pkgs,
  inputs,
  lib,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
  inherit (builtins) attrNames filter listToAttrs map readDir;
  localPackageNames = let
    entries = readDir ../../pkgs;
  in
    filter (name: entries.${name} == "directory") (attrNames entries);
  local =
    listToAttrs
    (map (name: {
        inherit name;
        value = pkgs.${name};
      })
      localPackageNames);
  battlenet = pkgs.writeShellScriptBin "battlenet" ''
    set -eu

    export WINEARCH=win64
    export WINEPREFIX="$HOME/.wine-battlenet"

    installer="$HOME/Downloads/Battle.net-Setup.exe"
    launcher="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
    wine="${pkgs.wineWow64Packages.stagingFull}/bin/wine"
    wineboot="${pkgs.wineWow64Packages.stagingFull}/bin/wineboot"
    winetricks="${unstable.winetricks}/bin/winetricks"

    if [ ! -f "$launcher" ]; then
      if [ ! -f "$installer" ]; then
        echo "Battle.net installer ontbreekt: $installer" >&2
        echo "Download Battle.net-Setup.exe van https://www.blizzard.com/apps/battle.net/desktop" >&2
        exit 1
      fi

      mkdir -p "$WINEPREFIX"
      "$wineboot" -u
      "$winetricks" -q dxvk
      exec "$wine" "$installer"
    fi

    exec "$wine" "$launcher"
  '';
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

    desktopEntries.battlenet = {
      name = "Battle.net";
      exec = "battlenet";
      terminal = false;
      categories = ["Game"];
      comment = "Launch Blizzard Battle.net via Wine";
      icon = "wine";
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

  home.packages = with pkgs; [
    # Wodan-specific Terminal packages go here
    amfora # Gemini Protocol Client (TUI)
    bombadillo # Gemini Protocol Client (TUI)
    kristall # Gemini Protocol Client
    lagrange # Gemini Protocol Client

    exfatprogs # ExFAT FS utilities
    helm
    k3d # k3s in docker
    flite # flite -f <file>; TTS Engine
    k3s # kubes (includes kubectl)
    postgresql # for psql; there's pgcli for shared
    redpanda-client # Kafka alternative
    tts # coqui-tts
    vimgolf # Vim golfing
    battlenet
    unstable.winetricks # unstable, so we can use 2026 version
    wineWow64Packages.stagingFull # include the Wine extras Battle.net tends to expect
    pulseaudio # provides pactl for PipeWire/PulseAudio debugging
    pavucontrol # Route PipeWire/PulseAudio app streams, e.g. Friture input from output monitor
    dotnet-sdk
    # ydotool # for voxtype
    # sqruff wrapped to avoid /bin/bench collision with ollama-cuda
    (sqruff.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          rm -f $out/bin/bench
        '';
    }))

    # Wodan-specific GUI packages go here
    # anki # Flashcard app
    # anydesk
    unstable.blender
    # dbeaver-bin # Database management tool
    # guacamole-client
    # guacamole-server
    (google-chrome.override {
      commandLineArgs = [
        "--enable-features=AcceleratedVideoEncoder"
        "--ignore-gpu-blocklist"
        "--enable-zero-copy"
      ];
    })
    itch # Game launcher
    libreoffice-qt6 # Office suite
    nuclear # Music player
    renderdoc # Graphics debugger
    # rustdesk
    # rustdesk-server
    slack # Slack messaging app
    wireguard-ui # WireGuard UI
    # xrdp # Remote Desktop Protocol client

    # GUI libs for Haemwend
    fontconfig
    freetype
    libGL
    libx11
    libxcursor
    libxext
    libxi
    libxrandr
    libxrender

    # games
    # unstable.openra_2019-release
    endless-sky
    godot
    unstable.openrct2

    # for stable-diffusion-webui
    gperftools

    # unstable
    unstable.friture # Real-time audio analyzer
    unstable.stable-diffusion-cpp # Stable Diffusion in C++
    # unstable.vllm # High-performance inference server for large language models
    # unstable.antigravity # Google IDE
    # unstable.opencode
    # unstable.ollama-cuda # Local LLM server
    # # Zed is slow to build :/
    # (unstable.zed-editor.overrideAttrs (_: {
    #   doCheck = false;
    # })) # Zed text editor

    # local.github-copilot-cli
    # local.synology-drive-client-pinned # kaput in 25.11
    # local.vscode
    local.cool-retro-term # terminal emulator with retro style
    local.dlss-updater
    local.photorec # image recovery
    # local.pixieditor
    local.pyre
  ];
}
