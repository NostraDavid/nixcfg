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
    wine64="${pkgs.wineWowPackages.stagingFull}/bin/wine64"
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
      exec "$wine64" "$installer"
    fi

    exec "$wine64" "$launcher"
  '';
in {
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
