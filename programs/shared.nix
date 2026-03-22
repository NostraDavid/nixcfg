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
  dpaintJsPort = 18087;
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
  xdg.desktopEntries = {
    firefox-esr = {
      name = "Firefox ESR";
      genericName = "Web Browser";
      exec = "firefox-esr %U";
      icon = "firefox-esr";
      terminal = false;
      type = "Application";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/vnd.mozilla.xul+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      startupNotify = true;
      settings = {
        StartupWMClass = "firefox";
        Actions = "new-private-window;new-window;profile-manager-window";
      };
      actions = {
        new-private-window = {
          name = "New Private Window";
          exec = "firefox-esr --private-window %U";
        };
        new-window = {
          name = "New Window";
          exec = "firefox-esr --new-window %U";
        };
        profile-manager-window = {
          name = "Profile Manager";
          exec = "firefox-esr --ProfileManager";
        };
      };
    };

    code = {
      name = "Visual Studio Code";
      genericName = "Text Editor";
      comment = "Code Editing. Redefined.";
      exec = "code %F";
      icon = "vscode";
      terminal = false;
      type = "Application";
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      startupNotify = true;
      settings = {
        StartupWMClass = "Code";
        Actions = "new-empty-window";
        Keywords = "vscode";
      };
      actions = {
        new-empty-window = {
          name = "New Empty Window";
          icon = "vscode";
          exec = "code --new-window %F";
        };
      };
    };
  };

  home.packages = with pkgs; [
    ## Terminal apps
    # mozjpeg # JPEG image optimizer - doesn't work with jpegli
    alejandra # nix formatter
    atuin # shell history manager
    bat # cat replacement
    btop # Resource monitor
    busybox
    colordiff # diff viewer
    csvkit # Python based CSV toolkit (heavier)
    curl
    cloc # Count lines of code
    delta # diff viewer
    diff-so-fancy # diff viewer
    difftastic # diff viewer
    diffutils # Diff
    direnv # Environment variable manager for dev
    dnsutils # `dig` + `nslookup`
    duckdb
    dust # better du called dust
    ed # The standard editor
    exiftool # for image metadata manipulation
    eza # modern replacement for `ls`
    fd # sometimes also fdfind or fd-find
    ffmpeg-full
    file # file type identifier
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
    go # the language
    graphicsmagick # image processing
    hadolint # Dockerfile linter
    helix # Text editor (hx)
    home-manager # Home Manager for managing user configurations
    htop # Resource monitor
    httpie # User-friendly HTTP client
    hyperfine # Command-line benchmarking tool
    image_optim # Image optimization tool
    imagemagick # image processing
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
    lazygit
    less # terminal pager
    lf # Terminal file manager
    libjpeg_turbo # JPEG tools including jpegtran
    lsd # A modern replacement for 'ls' command
    lsof # List open files
    lynx # Terminal-based web browser
    lz4 # Fastest compression algorithm
    meld # folder/file compare
    miller # CSV processor
    mlocate # locate command
    most # terminal pager
    msedit # Microsoft Editor
    mtr # A network diagnostic tool
    mutt # Terminal-based email client
    ncdu # Disk usage analyzer with ncurses interface
    netcat-gnu # nc
    newsboat # RSS reader
    nixd # nix LSP
    nnn # Terminal file manager
    nodejs_24 # for npx, for vscode
    nom # RSS reader
    nomacs # Image viewer
    ntfs3g # NTFS driver for work.
    nvme-cli # for nvme
    osv-scanner # Open Source Vulnerability Scanner
    osv-detector # Open Source Vulnerability Detector
    openssl # SSL/TLS toolkit
    optipng # PNG image optimizer
    oxipng # PNG image optimizer
    parallel # xarg alternative (except it actually runs in parallel)
    parquet-tools
    pciutils # for lspci
    pgcli # psql alternative
    pngquant # PNG image optimizer
    powerline # The best Bash Prompt!
    procs
    pv # Pipe viewer, useful for monitoring data through a pipe
    riffdiff # diff viewer
    ripgrep # Search tool (rg)
    rsync
    ruff
    sipcalc # Another IP calculator, with more features than ipcalc
    shellcheck
    shfmt # Shell script formatter
    smartmontools # for monitoring hard drive health
    sqlfluff # SQL linter and formatter
    sqlite
    sqls # SQL language server for Neovim
    starship # Shell prompt
    stow # GNU Stow for managing dotfiles
    strace
    svgo # SVG optimizer
    sysstat # for iostat
    tmux
    tree # Display directory structure in a tree-like format
    tree-sitter # used for Neovim
    ty # Astral type checker
    unzip
    util-linux # For `chrt` command
    uv # Astral project manager
    upx # Executable packer (binary compression)
    viddy # Watch alternative with better color support
    visidata # Interactive terminal multitool for tabular data
    w3m # Text-based web browser
    wget
    wl-clipboard # Clipboard management for Wayland
    xh # httpie and curl alternative
    xq-xml # XML processor
    xxd # Hex dump tool
    xz # Compression tool
    yank # yank terminal output to clipboard
    yq-go # YAML processor
    yt-dlp
    zellij # tmux alternative
    zoxide

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
    zstd # Fast compression algorithm with better ratio than lz4; contains zstdcat for decompression

    # Neovim related
    (unstable.neovim.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [wl-clipboard];
    }))
    jdk17 # openjdk for nvim-lsp-java
    luajit # Lua 5.1 compat
    luajitPackages.luarocks_bootstrap
    markdownlint-cli
    xclip # X11 clipboard fallback for Neovim when Wayland not active

    # unstable
    unstable.gemini-cli
    unstable.github-copilot-cli
    unstable.oxfmt # prettier replacement
    unstable.oxlint # js linter
    unstable.fastfetch # neofetch alternative
    unstable.zigfetch # neofetch alternative
    unstable.devenv # Development environment manager | using unstable for 2.x
    unstable.vscode
    unstable.codex # Code autocompletion tool

    # local
    freetype # font-rendering library, for Whatpulse
    libpcap # for Whatpulse
    local.jpegli
    local.whatpulse
    local.yafc
    local.xdgctl

    # podman
    podman-desktop # GUI for managing containers
    podman-compose # docker-compose alternative

    ## GUI apps
    # notepad-next # notepad alternative
    # fooyin # Music player # kaput in 25.11
    # remmina # Remote Desktop Protocol client
    chromium # Web browser
    evolution # Email client
    fsearch # Everything replacement
    geeqie # Image viewer
    ghostty # terminal
    gimp3 # Image editor
    gparted # Partition editor
    hardinfo2 # Temperature and system information tool
    keepassxc # Password manager
    legcord # Discord client
    loupe # Simple image viewer
    mission-center # Task Manager
    mpv # Media player
    pixelorama # Pixel art editor
    local.dpaint-js
    qbittorrent-enhanced # Torrent client
    qdirstat # Disk usage analyzer with Qt GUI
    rssguard # RSS reader
    signal-desktop # Signal messaging app
    speedcrunch # Calculator
    spotify
    synology-drive-client # Synology Drive client
    wezterm # Terminal emulator
    wireguard-tools # WireGuard tools
    xnviewmp # Image viewer
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

  systemd.user.services.dpaint-js = {
    Unit = {
      Description = "DPaint.js local web server";
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.python3} -m http.server ${toString dpaintJsPort} --bind 127.0.0.1 --directory ${local.dpaint-js}/share/dpaint-js";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
