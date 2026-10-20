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

  home.packages =
    [
      (stable.callPackage ../../pkgs/opencode-v2 {})
      (lib.hiPrio (stable.callPackage ../../pkgs/cmux-tui {}))
      stable.bashInteractive
      stable.iperf3
      stable.mc

      unstable.bat
      unstable.btop

      unstable.lsd

      unstable.starship
      unstable.tmux
      unstable.tree
    ]
    ++ lib.optionals stable.stdenv.hostPlatform.isDarwin [unstable.cmux];
}
