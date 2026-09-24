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
    stable.starship
    stable.tmux
  ];
}
