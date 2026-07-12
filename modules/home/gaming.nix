{
  inputs,
  pkgs,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
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
in {
  home.packages = with pkgs; [
    itch
    # Games
    # unstable.openra_2019-release
    endless-sky
    godot
    unstable.openrct2
    battlenet
    unstable.winetricks # unstable, so we can use 2026 version
    wineWow64Packages.stagingFull # include the Wine extras Battle.net tends to expect
  ];

  xdg.desktopEntries.battlenet = {
    name = "Battle.net";
    exec = "battlenet";
    terminal = false;
    categories = ["Game"];
    comment = "Launch Blizzard Battle.net via Wine";
    icon = "wine";
  };
}
