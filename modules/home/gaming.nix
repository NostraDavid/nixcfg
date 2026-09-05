{
  stable,
  unstable,
  ...
}: let
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
    battlenet = stable.writeShellScriptBin "battlenet" ''
      set -eu

      export WINEARCH=win64
      export WINEPREFIX="$HOME/.wine-battlenet"

      installer="$HOME/Downloads/Battle.net-Setup.exe"
      launcher="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
      wine="${stable.wineWow64Packages.stagingFull}/bin/wine"
      wineboot="${stable.wineWow64Packages.stagingFull}/bin/wineboot"
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
  };
in {
  home.packages = [
    inline.wow-wotlk
    inline.battlenet
    stable.endless-sky
    stable.godot
    unstable.itch
    stable.wineWow64Packages.stagingFull # include the Wine extras Battle.net tends to expect
    unstable.openrct2
    unstable.winetricks # unstable, so we can use 2026 version
  ];

  xdg.desktopEntries.wow-wotlk = {
    name = "WoW";
    exec = "env DXVK_FRAME_RATE=165 wow-wotlk --gplall --stock-config --profile";
    terminal = false;
    categories = ["Game"];
    comment = "Launch WoW 3.3.5a with DXVK, a 165 FPS limit and a frame-time graph";
    icon = "${./assets/wow.png}";
  };

  xdg.desktopEntries.battlenet = {
    name = "Battle.net";
    exec = "battlenet";
    terminal = false;
    categories = ["Game"];
    comment = "Launch Blizzard Battle.net via Wine";
    icon = "wine";
  };
}
