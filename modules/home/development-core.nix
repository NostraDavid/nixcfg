{
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}: let
  stable = pkgs;
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
in {
  home.packages =
    [
      # stable
      stable.alejandra
      stable.fd
      stable.fzf
      stable.git
      stable.lua-language-server
      stable.luajit
      stable.luajitPackages.luarocks_bootstrap
      stable.markdownlint-cli
      stable.nixd
      stable.ripgrep
      stable.selene
      stable.stylua
      stable.tree-sitter
      stable.wl-clipboard
      stable.xclip

      # unstable
      unstable.neovim
      unstable.mistral-vibe
    ]
    ++ lib.optionals (hostname != "bragi") [
      stable.codex
    ];
}
