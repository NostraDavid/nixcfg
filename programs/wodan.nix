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
in {
  home.packages = with pkgs; [
    # Wodan-specific Terminal packages go here
    exfatprogs # ExFAT FS utilities
    helm
    k3d # k3s in docker
    k3s # kubes (includes kubectl)
    postgresql # for psql; there's pgcli for shared
    redpanda-client # Kafka alternative
    tts # coqui-tts
    winetricks
    wineWowPackages.stable # support both 32-bit and 64-bit applications
    dotnet-sdk
    # pkgs-unstable.ollama-cuda # Local LLM server
    (pkgs-unstable.zed-editor.overrideAttrs (_: {
      doCheck = false;
    })) # Zed text editor

    # Wodan-specific GUI packages go here
    anydesk
    guacamole-client
    guacamole-server
    nomachine-client
    rustdesk
    rustdesk-server
    xrdp # Remote Desktop Protocol client
    anki # Flashcard app
    dbeaver-bin # Database management tool
    friture # Real-time audio analyzer
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

    # unstable
    pkgs-unstable.vllm # High-performance inference server for large language models

    # local
    # pkgs-local.github-copilot-cli
    pkgs-local.pixieditor
    # pkgs-local.nanocoder
    pkgs-local.photorec
    # pkgs-local.opencode
    # pkgs-local.vscode-pinned
    # pkgs-local.synology-drive-client-pinned # kaput in 25.11
    # pkgs-local.goose
    # pkgs-local.bitnet
  ];
}
