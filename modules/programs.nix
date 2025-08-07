# Home-manager configuration specific to the 'wodan' host.
{
  pkgs,
  inputs,
  ...
}: {
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
    eza
    fd # sometimes also fdfind or fd-find
    fzf # Fuzzy finder
    ffmpeg-full
    freetype
    gcc
    gh # GitHub CLI
    git # This will now use your pinned version (2.45.0)
    git-lfs # Git Large File Storage
    helix # Text editor (hx)
    helm
    home-manager # Home Manager for managing user configurations
    hyperfine # Command-line benchmarking tool
    image_optim # Image optimization tool
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
    mlocate # locate command
    mtr # A network diagnostic tool
    ncdu # Disk usage analyzer with ncurses interface
    gdu # Disk usage analyzer with Go
    nixd # nix LSP
    nnn # Terminal file manager
    ntfs3g # NTFS driver for work.
    optipng # PNG image optimizer
    oxipng # PNG image optimizer
    parallel
    powerline # The best Bash Prompt!
    pv # Pipe viewer, useful for monitoring data through a pipe
    qalculate-qt
    ripgrep # Search tool (rg)
    rsync
    ruff
    sqlfluff # SQL linter and formatter
    starship # Shell prompt
    stow # GNU Stow for managing dotfiles
    tmux
    tree # Display directory structure in a tree-like format
    ty # Astral type checker
    unzip
    uv # Astral project manager
    wget
    winetricks
    wineWowPackages.stable # support both 32-bit and 64-bit applications
    wl-clipboard # Clipboard management for Wayland
    xq-xml # XML processor
    yq-go # YAML processor
    yt-dlp

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
    anki
    chromium
    fooyin # Music player
    fsearch
    gimp3
    gparted
    itch
    keepassxc
    legcord # Discord client
    libreoffice-qt6
    loupe # Simple image viewer
    mission-center # Task Manager
    mpv
    remmina # Remote Desktop Protocol client
    signal-desktop
    slack
    speedcrunch
    synology-drive-client
    vscode
    wezterm
    wireguard-tools
    wireguard-ui
  ];
}
