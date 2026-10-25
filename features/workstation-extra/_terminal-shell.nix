{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.bc # Calculator
    stable.diffutils # Diff
    stable.file # File analysis
    stable.findutils # Finding
    stable.gnugrep # GNU grep
    stable.gnused # GNU sed
    stable.less # Terminal pager
    stable.most # Terminal pager
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
    unstable.vim # Classic editor
    unstable.zoxide # Directory jumper
  ];
}
