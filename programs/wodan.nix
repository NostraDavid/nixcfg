# Home-manager programs specific to wodan.
{
  pkgs,
  inputs,
  ...
}: let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
  inherit (builtins) attrNames filter listToAttrs map readDir;
  localPackageNames = let
    entries = readDir ../pkgs;
  in
    filter (name: entries.${name} == "directory") (attrNames entries);
  pkgs-local =
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
    wine="${pkgs.wineWowPackages.stagingFull}/bin/wine"
    wineboot="${pkgs.wineWowPackages.stagingFull}/bin/wineboot"
    winetricks="${pkgs.winetricks}/bin/winetricks"

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
in {
  programs.plasma = {
    enable = true;

    shortcuts = {
      "KDE Keyboard Layout Switcher" = {
        "Switch keyboard layout to A user-defined custom Layout" = "Control\\, Meta+Ctrl+Alt+Space";
        "Switch to Last-Used Keyboard Layout" = "Meta+Alt+L";
        "Switch to Next Keyboard Layout" = "Meta+Alt+K";
      };

      kaccess."Toggle Screen Reader On and Off" = "Meta+Alt+S";

      kmix = {
        decrease_microphone_volume = "Microphone Volume Down";
        decrease_volume = "Volume Down";
        decrease_volume_small = "Shift+Volume Down";
        increase_microphone_volume = "Microphone Volume Up";
        increase_volume = "Volume Up";
        increase_volume_small = "Shift+Volume Up";
        mic_mute = [
          "Microphone Mute"
          "Meta+Volume Mute"
        ];
        mute = "Volume Mute";
      };

      ksmserver = {
        "Lock Session" = [
          "Meta+L"
          "Screensaver"
        ];
        "Log Out" = "Ctrl+Alt+Del";
      };

      kwin = {
        "Activate Window Demanding Attention" = "Meta+Ctrl+A";
        "Edit Tiles" = "Meta+T";
        Expose = "Ctrl+F9";
        ExposeAll = [
          "Ctrl+F10"
          "Launch (C)"
        ];
        ExposeClass = "Ctrl+F7";
        "Grid View" = "Meta+G";
        "Kill Window" = "Meta+Ctrl+Esc";
        MoveMouseToCenter = "Meta+F6";
        MoveMouseToFocus = "Meta+F5";
        Overview = "Meta+W";
        "Show Desktop" = "Meta+D";
        "Suspend Compositing" = "Alt+Shift+F12";
        "Switch One Desktop Down" = "Meta+Ctrl+Down";
        "Switch One Desktop Up" = "Meta+Ctrl+Up";
        "Switch One Desktop to the Left" = "Meta+Ctrl+Left";
        "Switch One Desktop to the Right" = "Meta+Ctrl+Right";
        "Switch Window Down" = "Meta+Alt+Down";
        "Switch Window Left" = "Meta+Alt+Left";
        "Switch Window Right" = "Meta+Alt+Right";
        "Switch Window Up" = "Meta+Alt+Up";
        "Switch to Desktop 1" = "Ctrl+F1";
        "Switch to Desktop 2" = "Ctrl+F2";
        "Switch to Desktop 3" = "Ctrl+F3";
        "Switch to Desktop 4" = "Ctrl+F4";
        "Walk Through Windows" = "Alt+Tab";
        "Walk Through Windows (Reverse)" = "Alt+Shift+Tab";
        "Walk Through Windows of Current Application" = "Alt+`";
        "Walk Through Windows of Current Application (Reverse)" = "Alt+~";
        "Window Close" = "Alt+F4";
        "Window Maximize" = "Meta+PgUp";
        "Window Minimize" = "Meta+PgDown";
        "Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
        "Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
        "Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
        "Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
        "Window Operations Menu" = "Alt+F3";
        "Window Quick Tile Bottom" = "Meta+Down";
        "Window Quick Tile Left" = "Meta+Left";
        "Window Quick Tile Right" = "Meta+Right";
        "Window Quick Tile Top" = "Meta+Up";
        "Window to Next Screen" = "Meta+Shift+Right";
        "Window to Previous Screen" = "Meta+Shift+Left";
        disableInputCapture = "Meta+Shift+Esc";
        view_actual_size = "Meta+0";
        view_zoom_in = [
          "Meta++"
          "Meta+="
        ];
        view_zoom_out = "Meta+-";
      };

      mediacontrol = {
        nextmedia = "Media Next";
        pausemedia = "Media Pause";
        playpausemedia = "Media Play";
        previousmedia = "Media Previous";
        stopmedia = "Media Stop";
      };

      org_kde_powerdevil = {
        "Decrease Keyboard Brightness" = "Keyboard Brightness Down";
        "Decrease Screen Brightness" = "Monitor Brightness Down";
        "Decrease Screen Brightness Small" = "Shift+Monitor Brightness Down";
        Hibernate = "Hibernate";
        "Increase Keyboard Brightness" = "Keyboard Brightness Up";
        "Increase Screen Brightness" = "Monitor Brightness Up";
        "Increase Screen Brightness Small" = "Shift+Monitor Brightness Up";
        PowerDown = "Power Down";
        PowerOff = "Power Off";
        Sleep = "Sleep";
        "Toggle Keyboard Backlight" = "Keyboard Light On/Off";
        powerProfile = [
          "Battery"
          "Meta+B"
        ];
      };

      plasmashell = {
        "activate application launcher" = [
          "Meta"
          "Alt+F1"
        ];
        "activate task manager entry 1" = "Meta+1";
        "activate task manager entry 2" = "Meta+2";
        "activate task manager entry 3" = "Meta+3";
        "activate task manager entry 4" = "Meta+4";
        "activate task manager entry 5" = "Meta+5";
        "activate task manager entry 6" = "Meta+6";
        "activate task manager entry 7" = "Meta+7";
        "activate task manager entry 8" = "Meta+8";
        "activate task manager entry 9" = "Meta+9";
        clipboard_action = "Meta+Ctrl+X";
        cycle-panels = "Meta+Alt+P";
        "manage activities" = "Meta+Q";
        "next activity" = "Meta+A";
        "previous activity" = "Meta+Shift+A";
        "show dashboard" = "Ctrl+F12";
        show-on-mouse-pos = "Meta+V";
        "stop current activity" = "Meta+S";
      };
    };

    configFile = {
      baloofilerc = {
        "Basic Settings".Indexing-Enabled = false;
        General = {
          "exclude filters" = "*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found";
          "exclude filters version" = 9;
          "exclude folders[$e]" = "$HOME/data/";
          "only basic indexing" = true;
        };
      };

      kcminputrc = {
        "Libinput/1133/49970/Logitech Gaming Mouse G502".PointerAccelerationProfile = 1;
        Mouse = {
          X11LibInputXAccelProfileFlat = true;
          cursorSize = 36;
          cursorTheme = "breeze_cursors";
        };
      };

      kded5rc = {
        Module-browserintegrationreminder.autoload = false;
        Module-device_automounter.autoload = false;
      };

      kdeglobals = {
        General = {
          AccentColor = "61,174,233";
          BrowserApplication = "firefox-esr.desktop";
          LastUsedCustomAccentColor = "61,174,233";
        };
        Icons.Theme = "Win11-black-dark";
        KDE = {
          AnimationDurationFactor = 0.17677669529663687;
          AutomaticLookAndFeelOnIdle = false;
          DefaultDarkLookAndFeel = "com.github.yeyushengfan258.Win11OS-dark";
          widgetStyle = "Breeze";
        };
      };

      kiorc = {
        Confirmations = {
          ConfirmDelete = false;
          ConfirmEmptyTrash = true;
          ConfirmTrash = false;
        };
        "Executable scripts".behaviourOnLaunch = "execute";
      };

      krunnerrc.General = {
        FreeFloating = true;
        historyBehavior = "ImmediateCompletion";
      };

      kscreenlockerrc.Daemon = {
        Autolock = false;
        Timeout = 0;
      };

      ksplashrc.KSplash.Theme = "com.github.yeyushengfan258.Win11OS-dark";

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

      plasma-localerc.Formats = {
        LANG = "en_US.UTF-8";
        LC_TIME = "en_SE.UTF-8";
      };

      plasmarc.Theme.name = "Win11OS-dark";
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
      {
        screen = [
          0
          1
        ];
        location = "bottom";
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          {
            iconTasks = {
              launchers = [
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
            };
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
      }
    ];
  };

  xdg.desktopEntries.whatpulse = {
    name = "WhatPulse";
    genericName = "WhatPulse";
    comment = "Launch WhatPulse from the local AppImage";
    exec = "appimage-run /home/david/Desktop/whatpulse-linux-latest_amd64.AppImage";
    icon = "whatpulse";
    terminal = false;
    categories = ["Utility"];
  };

  xdg.configFile."autostart/io.github.martinrotter.rssguard.desktop".text = ''
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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };

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

  xdg.desktopEntries.battlenet = {
    name = "Battle.net";
    exec = "battlenet";
    terminal = false;
    categories = ["Game"];
    comment = "Launch Blizzard Battle.net via Wine";
    icon = "wine";
  };

  home.packages = with pkgs; [
    # Wodan-specific Terminal packages go here
    exfatprogs # ExFAT FS utilities
    helm
    k3d # k3s in docker
    k3s # kubes (includes kubectl)
    postgresql # for psql; there's pgcli for shared
    redpanda-client # Kafka alternative
    tts # coqui-tts
    vimgolf # Vim golfing
    battlenet
    winetricks
    wineWowPackages.stagingFull # include the Wine extras Battle.net tends to expect
    dotnet-sdk
    # ydotool # for voxtype
    # sqruff wrapped to avoid /bin/bench collision with ollama
    (sqruff.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          rm -f $out/bin/bench
        '';
    }))

    # Wodan-specific GUI packages go here
    anydesk
    blender
    guacamole-client
    guacamole-server
    nomachine-client
    rustdesk
    rustdesk-server
    xrdp # Remote Desktop Protocol client
    anki # Flashcard app
    dbeaver-bin # Database management tool
    itch # Game launcher
    libreoffice-qt6 # Office suite
    nuclear # Music player
    slack # Slack messaging app
    wireguard-ui # WireGuard UI

    # GUI libs for Haemwend
    xorg.libX11
    libGL
    xorg.libXrender
    xorg.libXext
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    fontconfig
    freetype

    # games
    endless-sky
    pkgs-unstable.openrct2
    godot

    # for stable-diffusion-webui
    gperftools

    # unstable
    pkgs-unstable.friture # Real-time audio analyzer
    pkgs-unstable.stable-diffusion-cpp # Stable Diffusion in C++
    # pkgs-unstable.vllm # High-performance inference server for large language models
    # pkgs-unstable.antigravity # Google IDE
    # pkgs-unstable.opencode
    # pkgs-unstable.ollama-cuda # Local LLM server
    # # Zed is slow to build :/
    # (pkgs-unstable.zed-editor.overrideAttrs (_: {
    #   doCheck = false;
    # })) # Zed text editor

    # local
    pkgs-local.codemogger
    pkgs-local.stable-diffusion-webui
    # pkgs-local.github-copilot-cli
    pkgs-local.pixieditor
    # pkgs-local.nanocoder
    pkgs-local.photorec
    # pkgs-local.opencode
    # pkgs-local.vscode-pinned
    # pkgs-local.synology-drive-client-pinned # kaput in 25.11
    # pkgs-local.goose
    # pkgs-local.bitnet
    # pkgs-local.voxtype
  ];
}
