{
  local,
  stable,
  unstable,
  ...
}: {
  home.packages = [
    (
      if stable.stdenv.hostPlatform.isDarwin
      then unstable.github-copilot-cli
      else local.github-copilot-cli
    )
    (
      if stable.stdenv.hostPlatform.isDarwin
      then unstable.jpegli
      else local.jpegli
    )
    local.codex # LLM Agent
    stable.cargo # Rust package manager
    stable.go # Go compiler
    stable.gradle # Build and test tool
    stable.mold # Fast linker
    stable.mosh # Mobile shell
    unstable.basedpyright # Python type checker
    unstable.cachix # Cachix CLI
    unstable.cloc # Count lines of code
    unstable.deadnix # Find unused dependencies in Nix projects
    unstable.entr # Run commands when files change
    unstable.gh # GitHub CLI
    unstable.hadolint # Dockerfile linter
    unstable.jjui # Jujutsu TUI
    unstable.lazydocker # Docker TUI
    unstable.lazyjj # Jujutsu TUI
    unstable.lightningcss # CSS parser and transformer
    unstable.mdp # Markdown pager
    unstable.mermaid-cli # Mermaid renderer
    unstable.nix-update # Update Nix package versions and hashes
    unstable.python313Packages.pynvim # Python support for Neovim
    unstable.rustscan # Network mapper
  ];
}
