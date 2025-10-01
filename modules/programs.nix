# Home-manager configuration specific to the 'wodan' host.
{
  pkgs,
  inputs,
  ...
}: let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config = pkgs.config // {allowUnfree = true;};
  };

in {
  # # Add the git version override
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     git = prev.git.overrideAttrs (oldAttrs: rec {
  #       version = "2.45.0"; # specify the version you want
  #       src = prev.fetchurl {
  #         url = "https://github.com/git/git/archive/v${version}.tar.gz";
  #         # nix-prefetch-url https://github.com/git/git/archive/v2.45.0.tar.gznix-prefetch-url https://github.com/git/git/archive/v2.45.0.tar.gz
  #         sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # you'll need to get the correct hash
  #       };
  #     });
  #   })
  # ];

  home.packages = with pkgs; [
    ## Terminal apps
    (neovim.overrideAttrs (old: {nativeBuildInputs = old.nativeBuildInputs ++ [wl-clipboard];}))
    alejandra # nix formatter
    atuin # shell history manager
    bat
    btop # Resource monitor
    curl
    direnv # Environment variable manager for dev
    dnsutils # `dig` + `nslookup`
    du-dust # better du called dust
    exfatprogs # ExFAT FS utilities
    eza # modern replacement for `ls`
    fd # sometimes also fdfind or fd-find
    ffmpeg-full
    freetype
    fzf # Fuzzy finder
    gcc
    gdu # Disk usage analyzer with Go
    gh # GitHub CLI
    git # This will now use your pinned version (2.45.0)
    git-lfs # Git Large File Storage
    glances # htop with temperature information
    helix # Text editor (hx)
    helm
    home-manager # Home Manager for managing user configurations
    htop # Resource monitor
    httpie # User-friendly HTTP client
    hyperfine # Command-line benchmarking tool
    image_optim # Image optimization tool
    inotify-tools # Tools to watch for file system events
    inxi # system information tool
    ipcalc # it is a calculator for the IPv4/v6 addresses
    jpegoptim # JPEG image optimizer
    jq # JSON processor
    just # justcfile
    k3d # k3s in docker
    k3s # kubes (includes kubectl)
    k9s # Kubernetes CLI tool
    kakoune # Text editor
    kdash # Kubernetes dashboard
    killall # kill processes by name
    lazygit
    lf # Terminal file manager
    libpcap # for Whatpulse
    lsof # List open files
    lynx # Terminal-based web browser
    mlocate # locate command
    mtr # A network diagnostic tool
    mutt # Terminal-based email client
    ncdu # Disk usage analyzer with ncurses interface
    newsboat # RSS reader
    nixd # nix LSP
    nnn # Terminal file manager
    nodejs_24 # for npx, for vscode
    nom # RSS reader
    ntfs3g # NTFS driver for work.
    ollama # Local LLM server
    optipng # PNG image optimizer
    oxipng # PNG image optimizer
    parallel
    powerline-go # Go implementation of powerline
    pv # Pipe viewer, useful for monitoring data through a pipe
    qalculate-qt
    redpanda-client # Kafka alternative
    ripgrep # Search tool (rg)
    rsync
    ruff
    shfmt # Shell script formatter
    sqlfluff # SQL linter and formatter
    sqruff # SQL formatter and linter
    starship # Shell prompt
    stow # GNU Stow for managing dotfiles
    tabby # Self-hosted AI coding assistant
    tabby-agent # Language server used to communicate with Tabby server
    tmux
    tree # Display directory structure in a tree-like format
    ty # Astral type checker
    unzip
    uv # Astral project manager
    viddy # Watch alternative with better color support
    w3m # Text-based web browser
    wget
    winetricks
    wineWowPackages.stable # support both 32-bit and 64-bit applications
    wl-clipboard # Clipboard management for Wayland
    xh # httpie and curl alternative
    xq-xml # XML processor
    yq-go # YAML processor
    yt-dlp

    # unstable
    pkgs-unstable.codex # Code autocompletion tool
    pkgs-unstable.vscode # Visual Studio Code

    # podman
    podman-desktop # GUI for managing containers
    podman-compose # docker-compose alternative

    # compression tools
    brotli
    bzip2
    gzip
    p7zip # 7zip command line tool
    pigz # Parallel implementation of gzip
    rar
    xz
    zip
    zopfli # For zopflipng; optimize PNG files

    ## GUI apps
    anki # Flashcard app
    chromium # Web browser
    evolution # Email client
    fluent-reader # RSS reader
    fooyin # Music player
    friture # Real-time audio analyzer
    fsearch # Everything replacement
    gimp3 # Image editor
    gparted # Partition editor
    hardinfo2 # Temperature and system information tool
    itch # Game launcher
    kdePackages.akregator # RSS reader
    keepassxc # Password manager
    legcord # Discord client
    libreoffice-qt6 # Office suite
    liferea # RSS reader
    loupe # Simple image viewer
    mission-center # Task Manager
    mpv # Media player
    newsflash # RSS reader
    nuclear # Music player
    qbittorrent-enhanced # Torrent client
    raven-reader # RSS reader
    remmina # Remote Desktop Protocol client
    rssguard # RSS reader
    notepad-next # notepad alternative
    signal-desktop # Signal messaging app
    slack # Slack messaging app
    speedcrunch # Calculator
    synology-drive-client # Synology Drive client
    wezterm # Terminal emulator
    wireguard-tools # WireGuard tools
    wireguard-ui # WireGuard UI
  ];
}
