# Shared Plasma configuration.
{lib, ...}: {
  home.activation.preparePlasmaBaloofile = lib.hm.dag.entryBetween ["configure-plasma"] ["writeBoundary"] ''
    target="$HOME/.config/baloofilerc"
    $DRY_RUN_CMD mkdir -p "$HOME/.config"
    if [ -L "$target" ]; then
      $DRY_RUN_CMD rm "$target"
    fi
  '';

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
        "Toggle Night Color" = "none";
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
        "Walk Through Windows" = [
          "Meta+Tab"
          "Alt+Tab"
        ];
        "Walk Through Windows (Reverse)" = [
          "Meta+Shift+Tab"
          "Alt+Shift+Tab"
        ];
        "Walk Through Windows of Current Application" = [
          "Meta+`"
          "Alt+`"
        ];
        "Walk Through Windows of Current Application (Reverse)" = [
          "Meta+~"
          "Alt+~"
        ];
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
        mediavolumedown = "none";
        mediavolumeup = "none";
        nextmedia = "Media Next";
        pausemedia = "Media Pause";
        playmedia = "none";
        playpausemedia = "Media Play";
        previousmedia = "Media Previous";
        seekbackwardmedia = "Media Rewind";
        seekbackwardmedialong = "none";
        seekforwardmedia = "Media Fast Forward";
        seekforwardmedialong = "none";
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

      "org.kde.systemsettings.desktop"._launch = "none";

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

      dolphinrc = {
        MenuBar.MenuBar = "Disabled";
        General = {
          Version = 202;
        };
        "KFileDialog Settings" = {
          "Places Icons Auto-resize" = false;
          "Places Icons Static Size" = 22;
        };
        MainWindow.MenuBar = "Disabled";
      };

      kded5rc = {
        Module-browserintegrationreminder.autoload = false;
        Module-device_automounter.autoload = false;
      };

      konsolerc = {
        General.ConfigVersion = 1;
        UiSettings.ColorScheme = "";
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

      plasma-localerc.Formats = {
        LANG = "en_US.UTF-8";
        LC_TIME = "en_SE.UTF-8";
      };

      plasmarc.Theme.name = "Win11OS-dark";
    };
  };
}
