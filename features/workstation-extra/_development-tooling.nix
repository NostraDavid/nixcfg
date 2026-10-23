{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.clang # C compiler for Neovim treesitter parsers
    stable.jdk17 # OpenJDK for nvim-lsp-java (17 for dbx compat)
    stable.luajit # Lua 5.1 compatibility
    stable.luajitPackages.luarocks_bootstrap # Lua package manager
    stable.zig # Zig compiler
    unstable.alejandra # Nix formatter
    unstable.ctx7 # Context7 documentation CLI
    unstable.dprint # Extensible code formatter
    unstable.markdownlint-cli # Markdown linter
    unstable.nixd # Nix LSP
    unstable.nixfmt # Nix formatter
    unstable.oxlint # JavaScript linter
    unstable.prek # Pre-commit-compatible hook runner
    unstable.pyrefly # Python type checker
    unstable.rubocop # Ruby linter
    unstable.ruby-lsp # Ruby language server
    unstable.ruff # Python linter and formatter
    unstable.shellcheck # Shell script analyzer
    unstable.shfmt # Shell formatter
    unstable.statix # Nix static analyzer
    unstable.ty # Python type checker
  ];
}
