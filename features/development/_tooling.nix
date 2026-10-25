{
  stable,
  unstable,
  ...
}: let
  litellmProxy = stable.python3.withPackages (ps:
    [
      ps.litellm
    ]
    ++ ps.litellm."optional-dependencies".proxy);
in {
  home.packages = [
    litellmProxy # LiteLLM with the proxy extra
    stable.gcc # C and C++ compiler toolchain
    stable.gcc-unwrapped # Provides libstdc++ for Python native extensions
    stable.go # Go compiler and toolchain
    stable.home-manager # Home Manager CLI
    stable.luajit # Lua 5.1 compatibility
    stable.luajitPackages.luarocks_bootstrap # Lua package manager for Neovim tooling
    stable.mold # Fast linker
    unstable.alejandra # Nix formatter
    unstable.bash-language-server # Bash LSP
    unstable.cachix # Binary cache CLI
    unstable.deadnix # Detect unused Nix code
    unstable.forgejo-cli # Forgejo CLI
    unstable.gh # GitHub CLI used by repository scripts
    unstable.hyperfine # Command-line benchmarking
    unstable.lua-language-server # Lua LSP for Neovim and Lua dotfiles
    unstable.markdownlint-cli # Markdown linter
    unstable.marksman # Markdown LSP
    unstable.nix-update # Update Nix package versions and hashes
    unstable.nixd # Nix LSP
    unstable.nixf-diagnose # Nix formatter
    unstable.pgformatter # PostgreSQL formatter
    unstable.plantuml # UML diagram renderer
    unstable.prek # pre-commit-compatible hook runner
    unstable.pyrefly # Python type checker
    unstable.python3Packages.jupytext # Represent notebooks as text
    unstable.python3Packages.scalene # Python profiler
    unstable.ruff # Python linter and formatter
    unstable.selene # Fast Lua linter/static analyzer
    unstable.shellcheck # Shell script analyzer
    unstable.shfmt # Shell script formatter
    unstable.sqlfluff # SQL linter and formatter
    unstable.sqls # SQL language server
    unstable.statix # Nix static analyzer
    unstable.stylua # Lua formatter used by conform.nvim
    unstable.taplo # TOML formatter and LSP
    unstable.ty # Python type checker
    unstable.vscode-langservers-extracted # HTML, CSS, JSON and ESLint language servers
    unstable.yaml-language-server # YAML LSP
    unstable.zuban # Mypy-compatible Python language server
  ];
}
