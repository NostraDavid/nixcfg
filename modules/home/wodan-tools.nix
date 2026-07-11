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
  ];
}
