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
  pkgs-local = pkgs.extend (_final: prev: {
    github-copilot-cli = prev.callPackage ../pkgs/github-copilot-cli {};
    # pixieditor = prev.callPackage ../pkgs/pixieditor {};
  });
in {
  home.packages = with pkgs; [
    ## Terminal apps
    # Astral project manager
    alejandra # nix formatter
    atuin # shell history manager
    bat # cat replacement
    btop # Resource monitor
    colordiff # diff viewer
    csvkit # Python based CSV toolkit (heavier)
    curl
    delta # diff viewer
    diff-so-fancy # diff viewer
    difftastic # diff viewer
    diffutils # Diff
    direnv # Environment variable manager for dev
    dnsutils # `dig` + `nslookup`
    du-dust # better du called dust
    duckdb
    exfatprogs # ExFAT FS utilities
    eza # modern replacement for `ls`
    fd # sometimes also fdfind or fd-find
    ffmpeg-full
    file # file type identifier
    flite # flite -f <file>
    freetype
    fzf # Fuzzy finder
    gcc
    gcc-unwrapped # to fix `ImportError: libstdc++.so.6: cannot open shared object file: No such file or directory` for numpy
    gdu # Disk usage analyzer with Go
    gh # GitHub CLI
    git # This will now use your pinned version (2.45.0)
    git-lfs # Git Large File Storage
    glances # htop with temperature information
    gnugrep # GNU grep
    gnused # GNU sed
    hadolint # Dockerfile linter
    helix # Text editor (hx)
    helm
    home-manager # Home Manager for managing user configurations
    htop # Resource monitor
    httpie # User-friendly HTTP client
    hyperfine # Command-line benchmarking tool
    image_optim # Image optimization tool
    inetutils # telnet
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
    less # terminal pager
    lf # Terminal file manager
    libpcap # for Whatpulse
    lsd # A modern replacement for 'ls' command
    lsof # List open files
    lynx # Terminal-based web browser
    miller # CSV processor
    mlocate # locate command
    most # terminal pager
    mtr # A network diagnostic tool
    mutt # Terminal-based email client
    ncdu # Disk usage analyzer with ncurses interface
    netcat-gnu
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
    parquet-tools
    powerline # The best Bash Prompt!
    procs
    pv # Pipe viewer, useful for monitoring data through a pipe
    qalculate-qt
    redpanda-client # Kafka alternative
    riffdiff # diff viewer
    ripgrep # Search tool (rg)
    rsync
    ruff
    shfmt # Shell script formatter
    sqlfluff # SQL linter and formatter
    sqlite
    sqruff # SQL formatter and linter
    starship # Shell prompt
    stow # GNU Stow for managing dotfiles
    strace
    tabby # Self-hosted AI coding assistant
    tabby-agent # Language server used to communicate with Tabby server
    tmux
    tree # Display directory structure in a tree-like format
    tts # coqui-tts
    ty # Astral type checker
    unzip
    util-linux # For `chrt` command
    viddy # Watch alternative with better color support
    visidata # Interactive terminal multitool for tabular data
    w3m # Text-based web browser
    wget
    winetricks
    wineWowPackages.stable # support both 32-bit and 64-bit applications
    wl-clipboard # Clipboard management for Wayland
    xh # httpie and curl alternative
    xq-xml # XML processor
    xz # Compression tool
    yq-go # YAML processor
    yt-dlp
    zopfli # For zopflipng; optimize PNG files
    zoxide
    zstd

    # Neovim related
    (pkgs-unstable.neovim.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [wl-clipboard];
    }))
    xclip # X11 clipboard fallback for Neovim when Wayland not active
    markdownlint-cli
    luajit # Lua 5.1 compat
    luajitPackages.luarocks_bootstrap
    jdk17 # openjdk for nvim-lsp-java
    dotnet-sdk

    # unstable
    pkgs-unstable.codex # Code autocompletion tool
    pkgs-unstable.vscode # Visual Studio Code
    pkgs-unstable.uv

    # local
    pkgs-local.github-copilot-cli
    pkgs-local.pixieditor

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
    dbeaver-bin # Database management tool
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
    notepad-next # notepad alternative
    nuclear # Music player
    qbittorrent-enhanced # Torrent client
    raven-reader # RSS reader
    remmina # Remote Desktop Protocol client
    rssguard # RSS reader
    signal-desktop # Signal messaging app
    slack # Slack messaging app
    speedcrunch # Calculator
    synology-drive-client # Synology Drive client
    wezterm # Terminal emulator
    wireguard-tools # WireGuard tools
    wireguard-ui # WireGuard UI
  ];
}
