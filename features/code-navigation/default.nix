{
  den.aspects.code-navigation.homeManager = {
    lib,
    local,
    unstable,
    ...
  }: {
    home.packages =
      [
        unstable.ast-grep # Structural search and rewrite previews
        unstable.cloc # Language and line counts for tracked source
        unstable.fd # Find source paths
        unstable.fzf # Fuzzy path and result selection
        unstable.python3Packages.lizard # Function complexity and duplicate analysis
        unstable.ripgrep # Exact text and candidate references
        unstable.sd # Text and regular expression replacements
        unstable.tree-sitter # Parse trees and language queries
        unstable.universal-ctags # Symbol definitions and file outlines
        local.probe # Ranked search and enclosing syntax extraction
      ]
      ++ lib.optionals (unstable.stdenv.hostPlatform.system == "x86_64-linux") [
        local.semble
      ];
  };
}
