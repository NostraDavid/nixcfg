{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.busybox # Compact collection of Unix utilities
    stable.diffutils # Standard diff utilities
    stable.ed # The standard editor
    stable.file # File type identification
    stable.gnugrep # GNU grep
    stable.gnused # GNU sed
    stable.killall # Kill processes by name
    stable.less # Terminal pager
    stable.mlocate # Locate files by name
    stable.most # Terminal pager with color support
    stable.powerline # Bash prompt and status line
    stable.wezterm # Terminal emulator
    stable.xxd # Hex dump utility
    stable.yank # Copy terminal output to the clipboard
    stable.ydotool # Desktop input (previously lean-ctx) automation
    unstable.atuin # Searchable shell history
    unstable.bat # cat replacement with syntax highlighting
    unstable.eza # Modern ls replacement
    unstable.glow # Terminal Markdown preview
    unstable.lf # Terminal file manager
    unstable.lsd # Modern ls replacement
    unstable.nnn # Terminal file manager
    unstable.parallel # Run shell jobs in parallel
    unstable.pv # Monitor data flowing through a pipe
    unstable.starship # Cross-shell prompt
    unstable.stow # Symlink-based dotfile manager
    unstable.tmux # Terminal multiplexer
    unstable.tree # Display directory trees
    unstable.viddy # Interactive watch alternative
    unstable.zellij # Terminal workspace and multiplexer
    unstable.zoxide # Directory jumper
  ];
}
