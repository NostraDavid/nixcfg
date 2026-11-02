{
  lib,
  stable,
  unstable,
  ...
}: {
  home.file = lib.optionalAttrs stable.stdenv.hostPlatform.isDarwin {
    ".local/bin/timeout".source = "${unstable.coreutils}/bin/timeout";
    ".local/bin/gtimeout".source = stable.writeShellScript "gtimeout" ''
      exec ${unstable.coreutils}/bin/timeout "$@"
    '';
  };

  home.packages = [
    (stable.callPackage ../../pkgs/opencode-v2 {})
    stable.age
    stable.bzip2 # Bzip2 compression
    stable.cpio # CPIO archives
    stable.curl # HTTP transfers
    stable.diffutils # File comparison
    stable.findutils # File search
    stable.gawk # Text processing
    stable.gnugrep # Text search
    stable.gnutar # Tar archives
    stable.gzip # Gzip compression
    stable.nano # Terminal editor
    stable.openssl # TLS and cryptography tools
    stable.patch # Apply patches
    stable.perl # Perl interpreter
    stable.rsync # File synchronization
    stable.time # Command timing
    stable.which # Command lookup
    stable.xz # XZ compression
    stable.zstd # Zstandard compression
    stable.bashInteractive
    stable.iperf3
    stable.mc
    unstable.bat
    unstable.btop
    unstable.lsd
    unstable.starship
    unstable.superfile
    unstable.tmux
    unstable.tree
    unstable.tuios
    unstable.vim
  ];
}
