# Home-manager programs shared across hosts.
{
  pkgs,
  inputs,
  lib,
  config,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
  inherit (builtins) attrNames filter listToAttrs map readDir;
  localPackageNames = let
    entries = readDir ../pkgs;
  in
    filter (name: entries.${name} == "directory") (attrNames entries);
  local =
    listToAttrs
    (map (name: {
        inherit name;
        value = pkgs.${name};
      })
      localPackageNames);
  hasDlssUpdater = lib.elem local.dlss-updater config.home.packages;
in {
  home.packages = with pkgs; [
    ## Terminal apps
    alejandra # nix formatter
    amfora # Gemini Protocol Client (TUI)
    atuin # shell history manager
    bat # cat replacement
    bombadillo # Gemini Protocol Client (TUI)
    btop # Resource monitor
    busybox
    colordiff # diff viewer
    csvkit # Python based CSV toolkit (heavier)
    curl
    delta # diff viewer
    diff-so-fancy # diff viewer
    difftastic # diff viewer
    diffutils # Diff
    direnv # Environment variable manager for dev
    dnsutils # `dig` + `nslookup`
    duckdb
    dust # better du called dust
    msedit # Microsoft Editor
    exiftool # for image metadata manipulation
    eza # modern replacement for `ls`
    fd # sometimes also fdfind or fd-find
    ffmpeg-full
    file # file type identifier
    flite # flite -f <file>; TTS Engine
    freetype
    fzf # Fuzzy finder
    gcc
    gcc-unwrapped # to fix `ImportError: libstdc++.so.6: cannot open shared object file: No such file or directory` for numpy
    gdu # Disk usage analyzer with Go
    gh # GitHub CLI
    ghostty # terminal
    git # This will now use your pinned version (2.45.0)
    git-lfs # Git Large File Storage
    glances # htop with temperature information
    gnugrep # GNU grep
    gnused # GNU sed
    graphicsmagick
    hadolint # Dockerfile linter
    helix # Text editor (hx)
    home-manager # Home Manager for managing user configurations
    htop # Resource monitor
    httpie # User-friendly HTTP client
    hyperfine # Command-line benchmarking tool
    image_optim # Image optimization tool
    imagemagick
    inetutils # telnet
    inotify-tools # Tools to watch for file system events
    inxi # system information tool
    iotop
    ipcalc # it is a calculator for the IPv4/v6 addresses
    jpeginfo # JPEG image validator
    jpegoptim # JPEG image optimizer
    jq # JSON processor
    just # justcfile
    k9s # Kubernetes CLI tool
    kakoune # Text editor
    kdash # Kubernetes dashboard
    killall # kill processes by name
    kristall # Gemini Protocol Client
    lagrange # Gemini Protocol Client
    lazygit
    less # terminal pager
    lf # Terminal file manager
    libpcap # for Whatpulse
    lsd # A modern replacement for 'ls' command
    lsof # List open files
    lynx # Terminal-based web browser
    lz4 # Fastest compression algorithm
    meld
    miller # CSV processor
    mlocate # locate command
    most # terminal pager
    # mozjpeg # JPEG image optimizer - doesn't work with jpegli
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
    nvme-cli # for nvme
    openssl # SSL/TLS toolkit
    optipng # PNG image optimizer
    oxipng # PNG image optimizer
    parallel
    parquet-tools
    pciutils # for lspci
    pgcli # psql alternative
    pngquant # PNG image optimizer
    powerline # The best Bash Prompt!
    procs
    pv # Pipe viewer, useful for monitoring data through a pipe
    renderdoc # Graphics debugger
    riffdiff # diff viewer
    ripgrep # Search tool (rg)
    rsync
    ruff
    shellcheck
    shfmt # Shell script formatter
    smartmontools # for monitoring hard drive health
    svgo # SVG optimizer
    sqlfluff # SQL linter and formatter
    sqlite
    starship # Shell prompt
    stow # GNU Stow for managing dotfiles
    strace
    sysstat # for iostat
    tmux
    tree # Display directory structure in a tree-like format
    ty # Astral type checker
    unzip
    util-linux # For `chrt` command
    viddy # Watch alternative with better color support
    visidata # Interactive terminal multitool for tabular data
    w3m # Text-based web browser
    wget
    wl-clipboard # Clipboard management for Wayland
    xh # httpie and curl alternative
    xq-xml # XML processor
    xxd # Hex dump tool
    xz # Compression tool
    yq-go # YAML processor
    yt-dlp
    zellij # tmux alternative
    zopfli # For zopflipng; optimize PNG files
    zoxide
    zstd # Fast compression algorithm with better ratio than lz4; contains zstdcat for decompression

    # Neovim related
    (unstable.neovim.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [wl-clipboard];
    }))
    xclip # X11 clipboard fallback for Neovim when Wayland not active
    markdownlint-cli
    luajit # Lua 5.1 compat
    luajitPackages.luarocks_bootstrap
    jdk17 # openjdk for nvim-lsp-java

    # unstable
    # unstable.openra_2019-release
    unstable.gemini-cli
    unstable.github-copilot-cli
    unstable.uv
    unstable.oxfmt # prettier replacement
    unstable.oxlint # js linter
    unstable.fastfetch # neofetch alternative
    unstable.zigfetch # neofetch alternative

    # local
    local.codex # Code autocompletion tool
    local.cool-retro-term # terminal emulator with retro style
    local.dlss-updater
    local.jpegli
    local.vscode-pinned

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
    chromium # Web browser
    evolution # Email client
    # fooyin # Music player # kaput in 25.11
    fsearch # Everything replacement
    gimp3 # Image editor
    gparted # Partition editor
    hardinfo2 # Temperature and system information tool
    keepassxc # Password manager
    legcord # Discord client
    loupe # Simple image viewer
    mission-center # Task Manager
    mpv # Media player
    notepad-next # notepad alternative
    spotify
    # qalculate-qt # use Speedcrunch instead
    qbittorrent-enhanced # Torrent client
    remmina # Remote Desktop Protocol client
    rssguard # RSS reader
    signal-desktop # Signal messaging app
    speedcrunch # Calculator
    synology-drive-client # Synology Drive client
    wezterm # Terminal emulator
    wireguard-tools # WireGuard tools
    qdirstat # Disk usage analyzer with Qt GUI
  ];

  home.activation.dlssUpdaterCleanup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Never exit from activation snippets; that would abort later phases
    # (including linkGeneration) and leave managed files stale.
    if ${lib.getExe pkgs.flatpak} --user info io.github.recol.dlss-updater >/dev/null 2>&1; then
      if ! ${lib.boolToString hasDlssUpdater}; then
        ${lib.getExe pkgs.flatpak} --user uninstall -y io.github.recol.dlss-updater || true
      fi
    fi
  '';
}
