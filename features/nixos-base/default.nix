{den, ...}: {
  den.aspects.nixos-base = {
    includes = with den.aspects; [
      cachix
      fonts
      internal-pki
    ];
    nixos = {
      pkgs,
      unstable,
      ...
    }: {
      environment.etc."xdg/plasma_workspace.notifyrc".text = ''
        [Event/notification]
        Action=Popup|Sound
        Sound=message
      '';
      programs.git = {
        enable = true;
        lfs.enable = true;
      };
      environment.systemPackages = [
        pkgs.age
        pkgs.bzip2 # Bzip2 compression
        pkgs.cpio # CPIO archives
        pkgs.curl # HTTP transfers
        pkgs.diffutils # File comparison
        pkgs.findutils # File search
        pkgs.gawk # Text processing
        pkgs.gnugrep # Text search
        pkgs.gnutar # Tar archives
        pkgs.gzip # Gzip compression
        pkgs.nano # Terminal editor
        pkgs.openssl # TLS and cryptography tools
        pkgs.patch # Apply patches
        pkgs.perl # Perl interpreter
        pkgs.rsync # File synchronization
        pkgs.time # Command timing
        pkgs.which # Command lookup
        pkgs.xz # XZ compression
        pkgs.zstd # Zstandard compression
        pkgs.iperf3
        pkgs.mc
        pkgs.neovim
        pkgs.opencode-v2
        pkgs.tree
        pkgs.vim
        unstable.superfile
        unstable.tuios
      ];
    };
  };
}
