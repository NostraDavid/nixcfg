{pkgs, ...}: let
  stable = pkgs;
  local = {inherit (pkgs) codex-security;};
in {
  home.packages = [
    ## Terminal apps
    # mozjpeg # JPEG image optimizer - doesn't work with jpegli
    stable.alejandra # nix formatter
    stable.atuin # shell history manager
    stable.bat # cat replacement
    stable.btop # Resource monitor
    stable.busybox
    stable.cachix # Cachix CLI
    stable.cloc # Count lines of code
    local.codex-security # Codex Security CLI
    stable.colordiff # diff viewer
    stable.csvkit # Python based CSV toolkit (heavier)
    stable.curl
    stable.deadnix # scan nix files for dead code
    stable.delta # diff viewer
    stable.diff-so-fancy # diff viewer
    stable.difftastic # diff viewer
    stable.diffutils # Diff
    stable.direnv # Environment variable manager for dev
    stable.dnsutils # `dig` + `nslookup`
    stable.duckdb
    stable.dust # better du called dust
    stable.ed # The standard editor
    stable.exiftool # for image metadata manipulation
    stable.eza # modern replacement for `ls`
    stable.fd # sometimes also fdfind or fd-find
    stable.ffmpeg-full
    stable.file # file type identifier
    stable.fzf # Fuzzy finder
    stable.gcc
    stable.gcc-unwrapped # to fix `ImportError: libstdc++.so.6: cannot open shared object file: No such file or directory` for numpy
    stable.gdu # Disk usage analyzer with Go
    stable.gh # GitHub CLI; used by grab.py
    stable.gifsicle # GIF image optimizer
    stable.git # This will now use your pinned version (2.45.0)
    stable.git-lfs # Git Large File Storage
    stable.glances # htop with temperature information
    stable.glow # Terminal Markdown preview
    stable.gnugrep # GNU grep
    stable.gnused # GNU sed
    stable.go # the language
    stable.gramps # Genealogy software
    stable.graphicsmagick # image processing
    stable.grype # Vulnerability scanner for SBOMs and container images
    stable.hadolint # Dockerfile linter
    stable.helix # Text editor (hx)
    stable.home-manager # Home Manager for managing user configurations
    stable.htop # Resource monitor
    stable.httpie # User-friendly HTTP client
    stable.hyperfine # Command-line benchmarking tool
    stable.image_optim # Image optimization tool
    stable.imagemagick # image processing
    stable.inetutils # telnet
    stable.inotify-tools # Tools to watch for file system events
    stable.inxi # system information tool
    stable.iotop
    stable.ipcalc # it is a calculator for the IPv4/v6 addresses
    stable.jpeginfo # JPEG image validator
    stable.jpegoptim # JPEG image optimizer
    stable.jq # JSON processor
    stable.jujutsu # jj version control
    stable.just # justfile
    stable.k9s # Kubernetes CLI tool
    stable.kakoune # Text editor
    stable.kdash # Kubernetes dashboard
    stable.killall # kill processes by name
    stable.lazygit
    stable.less # terminal pager
    stable.lf # Terminal file manager
    stable.libavif # for avifdec; AVIF image tools
    stable.libjpeg_turbo # JPEG tools including jpegtran
    stable.libjxl # for djxl; JPEG XL image tools
    stable.librsvg # for rsvg-convert; SVG image tools
    stable.libtiff # for tiffinfo, tiffcp, etc; TIFF image tools
    stable.libwebp # for dwebp; webp image tools
    stable.libxml2 # xmllint
    stable.lsd # A modern replacement for 'ls' command
    stable.lsof # List open files
    stable.lynx # Terminal-based web browser
    stable.lz4 # Fastest compression algorithm
    stable.meld # folder/file compare
    stable.mergiraf # Git merge tool
    stable.miller # CSV processor
    stable.mlocate # locate command
    stable.mold # a modern linker, for faster Rust compilation
    stable.most # terminal pager
    stable.msedit # Microsoft Editor
    stable.mtr # A network diagnostic tool
    stable.mutt # Terminal-based email client
    stable.ncdu # Disk usage analyzer with ncurses interface
    stable.netcat-gnu # nc
    stable.newsboat # RSS reader
    stable.nix-update # for just pkg-update ...
    stable.nixd # nix LSP
    stable.nnn # Terminal file manager
    stable.nodejs_24 # for npx, for vscode
    stable.nom # RSS reader
    stable.nomacs # Image viewer
    stable.ntfs3g # NTFS driver for work.
    stable.nvme-cli # for nvme
    stable.openssl # SSL/TLS toolkit
    stable.optipng # PNG image optimizer
    stable.osv-detector # Open Source Vulnerability Detector
    stable.osv-scanner # Open Source Vulnerability Scanner
    stable.oxipng # PNG image optimizer
    stable.parallel # xarg alternative (except it actually runs in parallel)
    stable.parquet-tools
    stable.pciutils # for lspci
    stable.pgcli # psql alternative
    stable.pgformatter # pg_format SQL formatter
    stable.plantuml # UML diagram renderer
    stable.pngcheck # PNG image validator
    stable.pngquant # PNG image optimizer
    stable.powerline # The best Bash Prompt!
    stable.prek # pre-commit alternative
    # prettier # disabled: 3.8.3 pulls insecure pnpm 9.15.9 via binding-wasm32-wasi
    stable.poppler-utils # PDF rendering library
    # prettierd # disabled with prettier; dprint is configured as its replacement
    stable.procps # for `ps` command
    stable.procs # moddern replacement for `ps`, written in Rust; might be troublesome
    stable.pv # Pipe viewer, useful for monitoring data through a pipe
    stable.pyrefly # Python type checker
    stable.python3Packages.jupytext # Jupyter notebooks as text
    stable.python3Packages.scalene # Python profiler
    stable.riffdiff # diff viewer
    stable.ripgrep # Search tool (rg)
    stable.rsync
    stable.ruff
    stable.sbomnix # SBOM generator for Nix closures
    stable.shellcheck
    stable.shfmt # Shell script formatter
    stable.sipcalc # Another IP calculator, with more features than ipcalc
    stable.smartmontools # for monitoring hard drive health
    stable.sqlfluff # SQL linter and formatter
    stable.sqlite
    stable.sqls # SQL language server for Neovim
    stable.starship # Shell prompt
    stable.statix # nix static code analyzer
    stable.stow # GNU Stow for managing dotfiles
    stable.strace
    stable.svgo # SVG optimizer
    stable.syft # SBOM generator and converter
    stable.sysstat # for iostat
    stable.tmux
    stable.tree # Display directory structure in a tree-like format
    stable.tree-sitter # used for Neovim
    stable.ty # Astral type checker
    stable.unzip
    stable.upx # Executable packer (binary compression)
    stable.util-linux # For `chrt` command
    stable.uv # Astral project manager
    stable.viddy # Watch alternative with better color support
    stable.visidata # Interactive terminal multitool for tabular data
    stable.vulnix # CVE scanner for Nix
    stable.w3m # Text-based web browser
    stable.wezterm # Terminal emulator
    stable.wget
    stable.wl-clipboard # Clipboard management for Wayland
    stable.xh # httpie and curl alternative
    stable.xq-xml # XML processor
    stable.xxd # Hex dump tool
    stable.xz # Compression tool
    stable.yank # yank terminal output to clipboard
    stable.yq-go # YAML processor
    stable.yt-dlp
    stable.zellij # tmux alternative
    stable.zoxide
    stable.zuban # Mypy-compatible Python Language Server built in Rust

    # compression tools
    stable.brotli
    stable.bzip2
    stable.gzip
    stable.p7zip # 7zip command line tool
    stable.pigz # Parallel implementation of gzip
    stable.rar
    stable.xz
    stable.zip
    stable.zopfli # For zopflipng; optimize PNG files
    stable.zstd # Fast compression algorithm with better ratio than lz4; contains zstdcat for decompression
  ];
}
