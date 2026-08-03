{stable, ...}: {
  home.packages = [
    stable.alejandra # Nix formatter
    stable.bash-language-server # Bash LSP
    stable.cachix # Binary cache CLI
    stable.cloc # Count lines of code
    stable.deadnix # Detect unused Nix code
    stable.gcc # C and C++ compiler toolchain
    stable.gcc-unwrapped # Provides libstdc++ for Python native extensions
    stable.gh # GitHub CLI used by repository scripts
    stable.go # Go compiler and toolchain
    stable.home-manager # Home Manager CLI
    stable.hyperfine # Command-line benchmarking
    stable.lua-language-server # Lua LSP for Neovim and Lua dotfiles
    stable.luajit # Lua 5.1 compatibility
    stable.luajitPackages.luarocks_bootstrap # Lua package manager for Neovim tooling
    stable.markdownlint-cli # Markdown linter
    stable.marksman # Markdown LSP
    stable.mold # Fast linker
    stable.nix-update # Update Nix package versions and hashes
    stable.nixd # Nix LSP
    stable.nixf-diagnose # Nix formatter
    stable.pgformatter # PostgreSQL formatter
    stable.plantuml # UML diagram renderer
    stable.prek # pre-commit-compatible hook runner
    stable.pyrefly # Python type checker
    stable.python3Packages.jupytext # Represent notebooks as text
    stable.python3Packages.scalene # Python profiler
    stable.ruff # Python linter and formatter
    stable.selene # Fast Lua linter/static analyzer
    stable.shellcheck # Shell script analyzer
    stable.shfmt # Shell script formatter
    stable.sqlfluff # SQL linter and formatter
    stable.sqls # SQL language server
    stable.statix # Nix static analyzer
    stable.stylua # Lua formatter used by conform.nvim
    stable.taplo # TOML formatter and LSP
    stable.ty # Python type checker
    stable.vscode-langservers-extracted # HTML, CSS, JSON and ESLint language servers
    stable.yaml-language-server # YAML LSP
    stable.zuban # Mypy-compatible Python language server
  ];
}
