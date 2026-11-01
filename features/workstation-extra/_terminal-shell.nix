{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.bc # Calculator
    stable.file # File analysis
    stable.gnused # GNU sed
    stable.powerline # Terminal prompt support
    stable.readline # Improved command-line editing
    stable.yank # Clipboard utility
    unstable.eza # ls replacement
    unstable.glow # Terminal Markdown renderer
    unstable.lf # Terminal file manager
    unstable.lsd # Modern ls replacement
    unstable.moor # Terminal pager
    unstable.nnn # Terminal file manager
    unstable.parallel # Parallel builds
    unstable.tealdeer # tldr in Rust
    unstable.tree # Display directory trees
    unstable.zoxide # Directory jumper
  ];
}
