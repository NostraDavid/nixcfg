{
  lib,
  stable,
  unstable,
  ...
}: {
  programs.direnv = {
    enable = true;
    package = unstable.direnv;
    nix-direnv.enable = true;
    nix-direnv.package = unstable.nix-direnv;
  };

  home.packages =
    [
      stable.nodejs_24 # JavaScript runtime and npx
      unstable.ast-grep # Structural code search and rewriting
      unstable.colordiff # Colorize diff output
      unstable.delta # Syntax-highlighting diff pager
      unstable.devenv # Development environment manager | using unstable for 2.x
      unstable.diff-so-fancy # Human-friendly diff formatter
      unstable.difftastic # Syntax-aware diff tool
      unstable.fd # Fast file finder
      unstable.fzf # Fuzzy finder
      unstable.git # Version control
      unstable.git-lfs # Git Large File Storage
      unstable.helix # Modal text editor
      unstable.jujutsu # Version control system
      unstable.just # Project command runner
      unstable.kakoune # Modal text editor
      unstable.lazygit # Terminal Git client
      unstable.mcporter # Discover and call MCP tools from the CLI
      unstable.mergiraf # Syntax-aware Git merge driver
      unstable.neovim # Primary editor
      unstable.riffdiff # Side-by-side diff viewer
      unstable.ripgrep # Fast recursive text search
      unstable.tree-sitter # Parser tooling used by Neovim
      unstable.uv # Python project and package manager
    ]
    ++ lib.optionals stable.stdenv.hostPlatform.isLinux [
      stable.alacritty # Alternative terminal emulator
      stable.bubblewrap # Linux sandbox for coding agents
      stable.ghostty # Primary terminal emulator
      stable.kitty # Alternative terminal emulator
      stable.wl-clipboard # Wayland clipboard integration for Neovim
      stable.xclip # X11 clipboard fallback when Wayland is not active
      unstable.msedit # Microsoft terminal editor
    ];
}
