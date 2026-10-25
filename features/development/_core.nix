{
  lib,
  local,
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
      unstable.alacritty # Alternative terminal emulator
      unstable.colordiff # Colorize diff output
      unstable.delta # Syntax-highlighting diff pager
      unstable.devenv # Development environment manager | using unstable for 2.x
      unstable.diff-so-fancy # Human-friendly diff formatter
      unstable.difftastic # Syntax-aware diff tool
      unstable.git # Version control
      unstable.git-lfs # Git Large File Storage
      unstable.helix # Modal text editor
      unstable.jujutsu # Version control system
      unstable.kakoune # Modal text editor
      unstable.kitty # Alternative terminal emulator
      unstable.lazygit # Terminal Git client
      unstable.mcporter # Discover and call MCP tools from the CLI
      unstable.mergiraf # Syntax-aware Git merge driver
      unstable.msedit # Microsoft terminal editor
      unstable.neovim # Primary editor
      unstable.riffdiff # Side-by-side diff viewer
      local.uv # Python project and package manager
    ]
    ++ lib.optionals unstable.stdenv.hostPlatform.isLinux [
      unstable.bubblewrap # Linux sandbox for coding agents
      unstable.ghostty # Primary terminal emulator
      unstable.wl-clipboard # Wayland clipboard integration for Neovim
      unstable.xclip # X11 clipboard fallback when Wayland is not active
    ]
    ++ lib.optionals unstable.stdenv.hostPlatform.isDarwin [
      unstable.ghostty-bin # Official macOS application
    ];
}
