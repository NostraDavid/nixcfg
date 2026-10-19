{
  stable,
  unstable,
  ...
}: {
  imports = [
    ./terminal/config.nix
    ./development/core.nix
    ./portable-dotfiles.nix
  ];

  home.packages = [
    stable.bashInteractive
    stable.iperf3
    stable.mc
    unstable.bat
    unstable.btop
    unstable.lsd
    unstable.starship
    unstable.tmux
    unstable.tree
  ];
}
