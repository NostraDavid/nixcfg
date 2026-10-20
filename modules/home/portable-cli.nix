{
  lib,
  stable,
  unstable,
  ...
}: {
  imports = [
    ./nix-index.nix
    ./terminal/config.nix
    ./development/core.nix
    ./darwin-speech.nix
    ./portable-dotfiles.nix
  ];

  home.file = lib.optionalAttrs stable.stdenv.hostPlatform.isDarwin {
    ".local/bin/timeout".source = "${unstable.coreutils}/bin/timeout";
    ".local/bin/gtimeout".source = stable.writeShellScript "gtimeout" ''
      exec ${unstable.coreutils}/bin/timeout "$@"
    '';
  };

  home.packages =
    [
      (stable.callPackage ../../pkgs/opencode-v2 {})
      (lib.hiPrio (stable.callPackage ../../pkgs/cmux-tui {}))
      stable.bashInteractive
      stable.iperf3
      stable.mc
      unstable.actionlint
      unstable.bat
      unstable.btop
      unstable.hurl
      unstable.lnav
      unstable.lsd
      unstable.nix-index
      unstable.nix-tree
      unstable.nvd
      unstable.sqruff
      unstable.starship
      unstable.tmux
      unstable.tree
      unstable.watchexec
    ]
    ++ lib.optionals stable.stdenv.hostPlatform.isDarwin [unstable.cmux];
}
