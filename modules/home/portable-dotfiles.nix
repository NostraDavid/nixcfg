{
  config,
  repoRoot,
  ...
}: let
  dot = "${repoRoot}/dotfiles";
  mk = path: config.lib.file.mkOutOfStoreSymlink path;
  forceAll = builtins.mapAttrs (_: file: file // {force = true;});
in {
  home.file = forceAll {
    "AGENTS.md".source = mk "${dot}/agents/instructions/AGENTS.md";
    ".agents/instructions".source = mk "${dot}/agents/instructions";
    ".agents/audio-notify".source = mk "${dot}/agents/.agents/audio-notify";
    ".codex/AGENTS.md".source = config.home.file."AGENTS.md".source;
    ".pi/agent/AGENTS.md".source = config.home.file."AGENTS.md".source;
    ".claude/CLAUDE.md".source = config.home.file."AGENTS.md".source;
    ".copilot/copilot-instructions.md".source = config.home.file."AGENTS.md".source;
    ".copilot/instructions/eu-ai-act.instructions.md".source = mk "${dot}/agents/instructions/eu-ai-act.md";
    ".config/opencode/AGENTS.md".source = config.home.file."AGENTS.md".source;
    ".config/cloc/options.txt".source = mk "${dot}/cloc-2.08/.config/cloc/options.txt";
    ".config/direnv/direnv.toml".source = mk "${dot}/direnv-2.36.0/.config/direnv/direnv.toml";
    ".config/dprint/dprint.jsonc".source = mk "${dot}/dprint-0.55.2/.config/dprint/dprint.jsonc";
    ".config/git/attributes".source = mk "${dot}/git-2.49.0/.config/git/attributes";
    ".config/git/commit-template".source = mk "${dot}/git-2.49.0/.config/git/commit-template";
    ".config/git/common.conf".source = mk "${dot}/git-2.49.0/.config/git/common.conf";
    ".config/git/hooks".source = mk "${dot}/git-2.49.0/.config/git/hooks";
    ".config/git/ignore".source = mk "${dot}/git-2.49.0/.config/git/ignore";
    ".config/lf/lfrc".source = mk "${dot}/lf-r41/.config/lf/lfrc";
    ".config/markdownlint/config.yaml".source = mk "${dot}/markdownlint-cli-0.48.0/.config/markdownlint/config.yaml";
    ".config/nix/nix.conf".source = mk "${dot}/nix-2.34.8/.config/nix/nix.conf";
    ".config/nvim/".source = mk "${dot}/neovim-0.11.2/.config/nvim";
    ".config/pip/pip.conf".source = mk "${dot}/pip-25.0.1/.config/pip/pip.conf";
    ".config/pypoetry/".source = mk "${dot}/pypoetry-2.1.3/.config/pypoetry";
    ".config/rtk/config.toml".source = mk "${dot}/rtk-0.41.0/.config/rtk/config.toml";
    ".config/topgrade.toml".source = mk "${dot}/topgrade-17.5.1/.config/topgrade/topgrade.toml";
    ".config/uv/uv.toml".source = mk "${dot}/uv-0.11.19/.config/uv/uv.toml";
    ".oxfmtrc.json".source = mk "${dot}/oxfmt-0.68.0/.oxfmtrc.json";
    ".oxlintrc.json".source = mk "${dot}/oxlint-1.85.0/.oxlintrc.json";
    ".rubocop.yml".source = mk "${dot}/ruby-3.3.8/.rubocop.yml";
    ".gitconfig".source = mk "${dot}/git-2.49.0/.gitconfig";
    ".vimrc".source = mk "${dot}/vim-9.1.1336/.vimrc";
  };
}
