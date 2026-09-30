{stable, ...}: {
  home.packages = [
    stable.bc # Calculator
    stable.diffutils # Diff
    stable.eza # ls replacement
    stable.file # File analysis
    stable.findutils # Finding
    stable.glow # Terminal Markdown renderer
    stable.gnugrep # GNU grep
    stable.gnused # GNU sed
    stable.less # Terminal pager
    stable.lf # Terminal file manager
    stable.lsd # Modern ls replacement
    stable.moor # Terminal pager
    stable.most # Terminal pager
    stable.nnn # Terminal file manager
    stable.parallel # Parallel builds
    stable.powerline # Terminal prompt support
    stable.readline # Improved command-line editing
    stable.sd # Find and replace tool
    stable.tealdeer # tldr in Rust
    stable.tree # Display directory trees
    stable.vim # Classic editor
    stable.yank # Clipboard utility
    stable.zellij # Terminal workspace and multiplexer
    stable.zoxide # Directory jumper
  ];
}
