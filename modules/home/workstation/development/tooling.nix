{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.alejandra # Nix formatter
    stable.clang # C compiler for Neovim treesitter parsers
    stable.jdk17 # OpenJDK for nvim-lsp-java (17 for dbx compat)
    stable.luajit # Lua 5.1 compatibility
    stable.luajitPackages.luarocks_bootstrap # Lua package manager
    stable.markdownlint-cli # Markdown linter
    stable.nixd # Nix LSP
    stable.nixfmt # Nix formatter
    stable.pyrefly # Python type checker
    stable.rubocop # Ruby linter
    stable.ruby-lsp # Ruby language server
    stable.shellcheck # Shell script analyzer
    stable.shfmt # Shell formatter
    stable.statix # Nix static analyzer
    stable.zig # Zig compiler
    unstable.ctx7 # Context7 documentation CLI
    unstable.dprint # Extensible code formatter
    unstable.just-lsp # Just language server
    unstable.oxlint # JavaScript linter
    unstable.prek # Pre-commit-compatible hook runner
    unstable.ruff # Python linter and formatter
    unstable.ty # Python type checker
  ];
}
