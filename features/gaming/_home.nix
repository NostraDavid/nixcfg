{
  stable,
  unstable,
  ...
}: let
  # FreeArc in the installer hangs in the new WoW64 mode (Wine bug 59472).
  warcraftWine = stable.wineWow64Packages.stagingFull.override {wineBuild = "wineWow";};
  wowStockDxvkConfig = stable.writeText "wow-dxvk-defaults.conf" "# Use DXVK defaults and built-in game compatibility settings.\n";
  wowGplall =
    stable.runCommand "wow-dxvk-gplall-2.6.8-2" {
      nativeBuildInputs = [stable.unzip];
      src = stable.fetchurl {
        url = "https://github.com/Digger1955/dxvk-gplall/releases/download/DXVK-GPLALL-2.6.8-2/DXVK-GPLALL-GCC-WinMacLinux-SSE2-O3-LTO.2.6.8-2.zip";
        hash = "sha256-Q5Gx2hkjCsF1SoCrBzEj7dmCMYdhUfpm50XFRT+nRyk=";
      };
    } ''
      mkdir -p "$out/x32"
      unzip -p "$src" x32/d3d9.dll > "$out/x32/d3d9.dll"
      test -s "$out/x32/d3d9.dll"
    '';
  wowMangoHudConfig = stable.writeText "wow-wotlk-MangoHud.conf" ''
    fps
    frametime
    frame_timing
    gpu_stats
    gpu_temp
    cpu_stats
    ram
    vram
    font_size=28
    position=top-right
    background_alpha=0.65
    log_interval=0
    log_duration=120
    toggle_logging=Shift_L+F2
    toggle_hud=Shift_R+F12
  '';
  inline = {
    warcraft-remastered = stable.writeShellApplication {
      name = "warcraft-remastered";
      runtimeInputs = [stable.coreutils stable.util-linux warcraftWine];
      text = ''
        export WINEARCH=win64
        export WINEPREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/warcraft-remastered"
        export WINEDEBUG="''${WINEDEBUG:--all}"
        game_dir="$WINEPREFIX/drive_c/Games/Warcraft Remastered"
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/warcraft-remastered"
        action="''${1:-}"
        if [ "$#" -gt 0 ]; then shift; fi
        case "$action" in
          install|1|2) ;;
          *) echo "Gebruik: warcraft-remastered {install [installatiemap]|1|2}" >&2; exit 2 ;;
        esac

        mkdir -p "$WINEPREFIX" "$state_dir"
        exec 9>"$WINEPREFIX/launcher.lock"
        if ! flock -n 9; then
          echo "Sluit eerst de actieve Warcraft-installatie of game af." >&2
          exit 1
        fi

        if [ "$action" = install ]; then
          installer_dir="''${1:-$HOME/data/torrents/Warcraft I & II Remastered [FitGirl Repack]}"
          if [ ! -f "$installer_dir/setup.exe" ]; then
            echo "Installer ontbreekt: $installer_dir/setup.exe" >&2
            exit 1
          fi
          wineboot -u
          cd "$installer_dir"
          wine setup.exe /SILENT /SUPPRESSMSGBOXES /NORESTART /SP- \
            '/DIR=C:\Games\Warcraft Remastered' /TASKS= '/LOG=C:\install.log'
          wineserver -w
          test -f "$game_dir/WC1/Warcraft.exe"
          test -f "$game_dir/WC2/Warcraft II.exe"
          exit 0
        fi

        case "$action" in
          1) game_dir="$game_dir/WC1"; executable=Warcraft.exe ;;
          2) game_dir="$game_dir/WC2"; executable="Warcraft II.exe" ;;
        esac
        if [ ! -f "$game_dir/$executable" ]; then
          echo "Warcraft ontbreekt. Voer eerst warcraft-remastered install uit." >&2
          exit 1
        fi
        wineboot -u >>"$state_dir/wineboot.log" 2>&1
        cd "$game_dir"
        wine "$executable" "$@" >>"$state_dir/warcraft-$action.log" 2>&1
        wineserver -w
      '';
    };
    wow-wotlk = stable.writeShellApplication {
      name = "wow-wotlk";
      runtimeInputs = [stable.coreutils stable.procps stable.util-linux];
      text = ''
        renderer=gplall
        profile=true
        stock_config=true
        export DXVK_FRAME_RATE="''${DXVK_FRAME_RATE:-165}"
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --wined3d) renderer=wined3d; profile=false ;;
            --dxvk) renderer=dxvk ;;
            --gplall) renderer=gplall ;;
            --profile) profile=true ;;
            --no-profile) profile=false ;;
            --stock-config) stock_config=true ;;
            --game-config) stock_config=false ;;
            --) shift; break ;;
            *) break ;;
          esac
          shift
        done
        if [ "$renderer" = wined3d ] && [ "$profile" = true ]; then
          echo "Gebruik --profile met DXVK of GPLALL." >&2
          exit 1
        fi

        game_dir="''${WOW_WOTLK_DIR:-$HOME/data/wow_3.3.5a}"
        if [ ! -f "$game_dir/Wow.exe" ]; then
          echo "WoW ontbreekt: $game_dir/Wow.exe" >&2
          exit 1
        fi
        if pgrep -u "$UID" -ix 'wow\.exe' >/dev/null; then
          echo "Sluit eerst de actieve WoW-sessie af." >&2
          exit 1
        fi

        export WINEARCH=win64
        export WINEPREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/wow-wotlk"
        export WINEDEBUG="''${WINEDEBUG:--all}"
        export DXVK_LOG_PATH="''${XDG_STATE_HOME:-$HOME/.local/state}/wow-wotlk"
        if [ "$renderer" = gplall ] || [ "$stock_config" = true ]; then
          DXVK_LOG_PATH="$DXVK_LOG_PATH/$renderer-stock-$stock_config"
        fi
        if [ "$stock_config" = true ]; then
          export DXVK_CONFIG_FILE="${wowStockDxvkConfig}"
          unset DXVK_CONFIG
        fi
        mkdir -p "$WINEPREFIX" "$DXVK_LOG_PATH"
        exec 9>"$WINEPREFIX/launcher.lock"
        if ! flock -n 9; then
          echo "De WoW-launcher is al actief." >&2
          exit 1
        fi

        # Update only this dedicated prefix before installing the 32-bit D3D9 DLL.
        "${stable.wineWow64Packages.stagingFull}/bin/wineboot" -u
        if [ "$renderer" != wined3d ]; then
          dxvk_dll="${stable.dxvk.bin}/x32/d3d9.dll"
          if [ "$renderer" = gplall ]; then
            dxvk_dll="${wowGplall}/x32/d3d9.dll"
          fi
          cp --remove-destination "$dxvk_dll" \
            "$WINEPREFIX/drive_c/windows/syswow64/d3d9.dll"
          export WINEDLLOVERRIDES="d3d9=n"
          export DXVK_HUD="''${DXVK_HUD:-version,fps,frametimes,gpuload,compiler,scale=1.5,opacity=0.85}"
        else
          export WINEDLLOVERRIDES="d3d9=b"
        fi

        cd "$game_dir"
        if [ "$profile" = true ]; then
          mkdir -p "$DXVK_LOG_PATH/performance"
          export DXVK_HUD="compiler,scale=1.5"
          export MANGOHUD_CONFIGFILE="${wowMangoHudConfig}"
          export MANGOHUD_CONFIG="read_cfg,output_folder=$DXVK_LOG_PATH/performance"
          exec "${stable.mangohud}/bin/mangohud" \
            "${stable.wineWow64Packages.stagingFull}/bin/wine" Wow.exe -d3d9 "$@"
        fi
        exec "${stable.wineWow64Packages.stagingFull}/bin/wine" Wow.exe -d3d9 "$@"
      '';
    };
  };
in {
  home.packages = [
    inline.warcraft-remastered
    inline.wow-wotlk
    stable.endless-sky
    stable.godot
    unstable.itch
    unstable.openrct2
  ];

  xdg.desktopEntries = {
    warcraft-1-remastered = {
      name = "Warcraft I Remastered";
      exec = "warcraft-remastered 1";
      terminal = false;
      categories = ["Game" "StrategyGame"];
      icon = "wine";
    };

    warcraft-2-remastered = {
      name = "Warcraft II Remastered";
      exec = "warcraft-remastered 2";
      terminal = false;
      categories = ["Game" "StrategyGame"];
      icon = "wine";
    };

    wow-wotlk = {
      name = "WoW";
      exec = "env DXVK_FRAME_RATE=165 wow-wotlk --gplall --stock-config --profile";
      terminal = false;
      categories = ["Game"];
      comment = "Launch WoW 3.3.5a with DXVK, a 165 FPS limit and a frame-time graph";
      icon = "${./assets/wow.png}";
    };
  };
}
