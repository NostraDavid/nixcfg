{
  lib,
  local,
  stable,
  unstable,
  ...
}: {
  home.packages =
    [
      stable.basedpyright # Python type checker
      stable.cachix # Cachix CLI
      stable.cargo # Rust package manager
      stable.claude-code # LLM Agent
      stable.cloc # Count lines of code
      stable.deadnix # Find unused dependencies in Nix projects
      stable.entr # Run commands when files change
      stable.gh # GitHub CLI
      stable.go # Go compiler
      stable.gradle # Build and test tool
      stable.hadolint # Dockerfile linter
      stable.jjui # Jujutsu TUI
      stable.lazydocker # Docker TUI
      stable.lazyjj # Jujutsu TUI
      stable.lightningcss # CSS parser and transformer
      stable.mdp # Markdown pager
      stable.mermaid-cli # Mermaid renderer
      stable.mold # Fast linker
      stable.mosh # Mobile shell
      stable.nix-update # Update Nix package versions and hashes
      stable.opencode # LLM Agent
      stable.rustscan # Network mapper
      stable.watchexec # Run commands in response to file changes
      unstable.python313Packages.pynvim # Python support for Neovim
    ]
    ++ lib.optionals stable.stdenv.isLinux [
      local.github-copilot-cli # LLM Agent
      local.codex # LLM Agent
      local.jpegli
    ];
}
