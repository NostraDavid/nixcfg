{
  hostname,
  lib,
  stable,
  unstable,
  ...
}: {
  programs.direnv = {
    enable = true;
    config.global = {
      hide_env_diff = true;
      disable_stdin = true;
      warn_timeout = "15s";
    };
    nix-direnv.enable = true;
  };

  home.packages =
    [
      stable.colordiff # Colorize diff output
      stable.delta # Syntax-highlighting diff pager
      stable.diff-so-fancy # Human-friendly diff formatter
      stable.difftastic # Syntax-aware diff tool
      stable.fd # Fast file finder
      stable.fzf # Fuzzy finder
      stable.ghostty # Primary terminal emulator
      stable.git # Version control
      stable.git-lfs # Git Large File Storage
      stable.helix # Modal text editor
      stable.jujutsu # Version control system
      stable.just # Project command runner
      stable.kakoune # Modal text editor
      stable.lazygit # Terminal Git client
      stable.mergiraf # Syntax-aware Git merge driver
      stable.nodejs_24 # JavaScript runtime and npx
      stable.riffdiff # Side-by-side diff viewer
      stable.ripgrep # Fast recursive text search
      stable.tree-sitter # Parser tooling used by Neovim
      stable.wl-clipboard # Wayland clipboard integration for Neovim
      stable.xclip # X11 clipboard fallback when Wayland is not active
      unstable.devenv # Development environment manager | using unstable for 2.x
      unstable.msedit # Microsoft terminal editor
      unstable.neovim # Primary editor
      unstable.uv # Python project and package manager
    ]
    ++ lib.optionals (hostname != "bragi") [
      unstable.codex # OpenAI coding agent; omitted on resource-constrained Bragi
    ];
}
