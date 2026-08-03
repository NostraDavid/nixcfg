{
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}: let
  stable = pkgs;
  unstable = import inputs.nixpkgs-unstable {
    inherit (stable.stdenv.hostPlatform) system;
    config = stable.config // {allowUnfree = true;};
  };
  local = {inherit (pkgs) codex;};
in {
  home.packages =
    [
      # Stable development essentials
      stable.alejandra # Nix formatter
      stable.bash-language-server # Bash LSP
      stable.fd # Fast file finder
      stable.fzf # Fuzzy finder
      stable.ghostty # Primary terminal emulator
      stable.git # Version control
      stable.lua-language-server # Lua LSP for Neovim and Lua dotfiles
      stable.luajit # Lua 5.1 compatibility
      stable.luajitPackages.luarocks_bootstrap # Lua package manager for Neovim tooling
      stable.marksman # Markdown LSP
      stable.markdownlint-cli # Markdown linter
      stable.nixd # Nix LSP
      stable.ripgrep # Fast recursive text search
      stable.selene # Fast Lua linter/static analyzer
      stable.stylua # Lua formatter used by conform.nvim
      stable.taplo # TOML formatter and LSP
      stable.tree-sitter # Parser tooling used by Neovim
      stable.ty # Python type checker
      stable.vscode-langservers-extracted # HTML, CSS, JSON and ESLint language servers
      stable.wl-clipboard # Wayland clipboard integration for Neovim
      stable.xclip # X11 clipboard fallback when Wayland is not active
      stable.yaml-language-server # YAML LSP

      # Unstable development tools
      unstable.neovim # Primary editor
      unstable.mistral-vibe # Mistral coding agent
    ]
    ++ lib.optionals (hostname != "bragi") [
      local.codex # OpenAI coding agent; omitted on resource-constrained Bragi
    ];
}
