{stable, ...}: {
  home.packages = [
    stable.atuin # Searchable shell history
    stable.bat # cat replacement with syntax highlighting
    stable.busybox # Compact collection of Unix utilities
    stable.diffutils # Standard diff utilities
    stable.ed # The standard editor
    stable.eza # Modern ls replacement
    stable.file # File type identification
    stable.glow # Terminal Markdown preview
    stable.gnugrep # GNU grep
    stable.gnused # GNU sed
    stable.killall # Kill processes by name
    stable.less # Terminal pager
    stable.lf # Terminal file manager
    stable.lsd # Modern ls replacement
    stable.mlocate # Locate files by name
    stable.most # Terminal pager with color support
    stable.nnn # Terminal file manager
    stable.parallel # Run shell jobs in parallel
    stable.powerline # Bash prompt and status line
    stable.pv # Monitor data flowing through a pipe
    stable.starship # Cross-shell prompt
    stable.stow # Symlink-based dotfile manager
    stable.tmux # Terminal multiplexer
    stable.tree # Display directory trees
    stable.viddy # Interactive watch alternative
    stable.wezterm # Terminal emulator
    stable.xxd # Hex dump utility
    stable.yank # Copy terminal output to the clipboard
    stable.zellij # Terminal workspace and multiplexer
    stable.zoxide # Directory jumper
  ];
}
