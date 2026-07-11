{pkgs, ...}: {
  home.packages = with pkgs; [
    ## Terminal apps
    # mozjpeg # JPEG image optimizer - doesn't work with jpegli
    alejandra # nix formatter
    atuin # shell history manager
    bat # cat replacement
    btop # Resource monitor
    busybox
    cachix # Cachix CLI
    cloc # Count lines of code
    colordiff # diff viewer
    csvkit # Python based CSV toolkit (heavier)
    curl
    deadnix # scan nix files for dead code
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
    gh # GitHub CLI; used by grab.py
    gifsicle # GIF image optimizer
    git # This will now use your pinned version (2.45.0)
    git-lfs # Git Large File Storage
    glances # htop with temperature information
    glow # Terminal Markdown preview
    gnugrep # GNU grep
    gnused # GNU sed
    go # the language
    gramps # Genealogy software
    graphicsmagick # image processing
    grype # Vulnerability scanner for SBOMs and container images
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
    jujutsu # jj version control
    just # justfile
    k9s # Kubernetes CLI tool
    kakoune # Text editor
    kdash # Kubernetes dashboard
    killall # kill processes by name
    lazygit
    less # terminal pager
    lf # Terminal file manager
    libavif # for avifdec; AVIF image tools
    libjpeg_turbo # JPEG tools including jpegtran
    libjxl # for djxl; JPEG XL image tools
    librsvg # for rsvg-convert; SVG image tools
    libtiff # for tiffinfo, tiffcp, etc; TIFF image tools
    libwebp # for dwebp; webp image tools
    libxml2 # xmllint
    llama-cpp # for Blender MCP
    lsd # A modern replacement for 'ls' command
    lsof # List open files
    lynx # Terminal-based web browser
    lz4 # Fastest compression algorithm
    meld # folder/file compare
    mergiraf # Git merge tool
    miller # CSV processor
    mlocate # locate command
    mold # a modern linker, for faster Rust compilation
    most # terminal pager
    msedit # Microsoft Editor
    mtr # A network diagnostic tool
    mutt # Terminal-based email client
    ncdu # Disk usage analyzer with ncurses interface
    netcat-gnu # nc
    newsboat # RSS reader
    nix-update # for just pkg-update ...
    nixd # nix LSP
    nnn # Terminal file manager
    nodejs_24 # for npx, for vscode
    nom # RSS reader
    nomacs # Image viewer
    ntfs3g # NTFS driver for work.
    nvme-cli # for nvme
    openssl # SSL/TLS toolkit
    optipng # PNG image optimizer
    osv-detector # Open Source Vulnerability Detector
    osv-scanner # Open Source Vulnerability Scanner
    oxipng # PNG image optimizer
    parallel # xarg alternative (except it actually runs in parallel)
    parquet-tools
    pciutils # for lspci
    pgcli # psql alternative
    pgformatter # pg_format SQL formatter
    plantuml # UML diagram renderer
    pngcheck # PNG image validator
    pngquant # PNG image optimizer
    powerline # The best Bash Prompt!
    prek # pre-commit alternative
    prettier # Web/JSON/YAML/Markdown formatter
    poppler-utils # PDF rendering library
    prettierd # Prettier daemon
    procps # for `ps` command
    procs # moddern replacement for `ps`, written in Rust; might be troublesome
    pv # Pipe viewer, useful for monitoring data through a pipe
    pyrefly # Python type checker
    python3Packages.jupytext # Jupyter notebooks as text
    python3Packages.scalene # Python profiler
    riffdiff # diff viewer
    ripgrep # Search tool (rg)
    rsync
    ruff
    sbomnix # SBOM generator for Nix closures
    shellcheck
    shfmt # Shell script formatter
    sipcalc # Another IP calculator, with more features than ipcalc
    smartmontools # for monitoring hard drive health
    sqlfluff # SQL linter and formatter
    sqlite
    sqls # SQL language server for Neovim
    starship # Shell prompt
    statix # nix static code analyzer
    stow # GNU Stow for managing dotfiles
    strace
    svgo # SVG optimizer
    syft # SBOM generator and converter
    sysstat # for iostat
    tmux
    tree # Display directory structure in a tree-like format
    tree-sitter # used for Neovim
    ty # Astral type checker
    unzip
    upx # Executable packer (binary compression)
    util-linux # For `chrt` command
    uv # Astral project manager
    viddy # Watch alternative with better color support
    visidata # Interactive terminal multitool for tabular data
    vulnix # CVE scanner for Nix
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
    wezterm # Terminal emulator

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
  ];
}
