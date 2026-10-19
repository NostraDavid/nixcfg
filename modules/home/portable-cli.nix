{
  lib,
  stable,
  unstable,
  ...
}: {
  imports = [
    ./terminal/config.nix
    ./development/core.nix
    ./portable-dotfiles.nix
  ];

  home.file = lib.optionalAttrs stable.stdenv.hostPlatform.isDarwin {
    ".local/bin/timeout".source = "${unstable.coreutils}/bin/timeout";
    ".local/bin/gtimeout".source = stable.writeShellScript "gtimeout" ''
      exec ${unstable.coreutils}/bin/timeout "$@"
    '';
  };

  home.packages = [
    (stable.callPackage ../../pkgs/opencode-v2 {})
    (
      if stable.stdenv.hostPlatform.isDarwin
      then unstable.cmux
      else stable.cmux-tui
    )
    stable.bashInteractive
    stable.iperf3
    stable.mc
    unstable.bat
    unstable.btop
    unstable.hurl
    unstable.lsd
    unstable.sqruff
    unstable.starship
    unstable.tmux
    unstable.tree
  ];
}
