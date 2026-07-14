{
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
in {
  home.packages =
    (with pkgs; [
      # stable
      alejandra
      fd
      fzf
      git
      lua-language-server
      luajit
      luajitPackages.luarocks_bootstrap
      markdownlint-cli
      nixd
      ripgrep
      selene
      stylua
      tree-sitter
      wl-clipboard
      xclip

      # unstable
      unstable.neovim
    ])
    ++ lib.optionals (hostname != "bragi") [
      pkgs.codex
    ];
}
