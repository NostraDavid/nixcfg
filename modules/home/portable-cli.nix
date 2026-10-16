{stable, ...}: {
  imports = [
    ./terminal/config.nix
    ./development/core.nix
    ./portable-dotfiles.nix
  ];

  home.packages = [
    stable.bashInteractive
    stable.bat
    stable.btop
    stable.iperf3
    stable.mc
    stable.starship
    stable.tmux
    stable.tree
  ];
}
