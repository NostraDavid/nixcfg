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
    ".config/cloc/options.txt".source = mk "${dot}/cloc-2.08/.config/cloc/options.txt";
    ".config/dprint/dprint.jsonc".source = mk "${dot}/dprint-0.54.0/.config/dprint/dprint.jsonc";
    ".config/git/attributes".source = mk "${dot}/git/.config/git/attributes";
    ".config/git/commit-template".source = mk "${dot}/git/.config/git/commit-template";
    ".config/git/common.conf".source = mk "${dot}/git/.config/git/common.conf";
    ".config/git/hooks".source = mk "${dot}/git/.config/git/hooks";
    ".config/git/ignore".source = mk "${dot}/git/.config/git/ignore";
    ".config/lf/lfrc".source = mk "${dot}/lf-r35/.config/lf/lfrc";
    ".config/markdownlint/config.yaml".source = mk "${dot}/markdownlint-cli-0.46.0/.config/markdownlint/config.yaml";
    ".config/nix/nix.conf".source = mk "${dot}/nix-2.21.1/.config/nix/nix.conf";
    ".config/nvim/".source = mk "${dot}/neovim-0.11/.config/nvim";
    ".config/pip/pip.conf".source = mk "${dot}/pip-22+/.config/pip/pip.conf";
    ".config/pypoetry/".source = mk "${dot}/pypoetry-2.1/.config/pypoetry";
    ".config/rtk/config.toml".source = mk "${dot}/rtk-0.41.0/.config/rtk/config.toml";
    ".config/topgrade.toml".source = mk "${dot}/topgrade-16.6.1/.config/topgrade/topgrade.toml";
    ".config/uv/uv.toml".source = mk "${dot}/uv-0.9.0/.config/uv/uv.toml";
    ".oxfmtrc.json".source = mk "${dot}/oxfmt-0.23.0/.oxfmtrc.json";
    ".oxlintrc.json".source = mk "${dot}/oxlint-1.41.0/.oxlintrc.json";
    ".rubocop.yml".source = mk "${dot}/ruby-3.3/.rubocop.yml";
    ".git-templates".source = mk "${dot}/git-templates/.git-templates";
    ".gitconfig".source = mk "${dot}/git/.gitconfig";
    ".vimrc".source = mk "${dot}/vim-9.0/.vimrc";
  };
}
