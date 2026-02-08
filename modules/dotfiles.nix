# home/common.nix
# Shared home-manager configuration for all hosts.
{config, ...}: {
  # This list may look a little weird, but that's because the original dotfiles
  # were managed by `stow`, which needs this folder structure to work correctly.
  # I decided to keep it that way, so I could return to stow in the future.
  home.file = let
    dot = "${config.home.homeDirectory}/dev/NostraDavid/nixcfg/dotfiles";
    mk = path: config.lib.file.mkOutOfStoreSymlink path;
  in {
    ".bash_aliases".source = mk "${dot}/bash-5.2.37/.bash_aliases";
    ".bash_profile".source = mk "${dot}/bash-5.2.37/.bash_profile";
    ".bashrc".source = mk "${dot}/bash-5.2.37/.bashrc";
    ".config/bat/config".source = mk "${dot}/bat-0.25.0/.config/bat/config";
    ".config/nvim/".source = mk "${dot}/neovim-0.11/.config/nvim";
    ".config/pip/pip.conf".source = mk "${dot}/pip-22+/.config/pip/pip.conf";
    ".config/powerline".source = mk "${dot}/powerline-bash/.config/powerline";
    ".config/pypoetry/".source = mk "${dot}/pypoetry-2.1/.config/pypoetry";
    ".config/starship.toml".source = mk "${dot}/starship-1.23.0/.config/starship.toml";
    # ".config/voxtype/config.toml".source = mk "${dot}/voxtype/.config/voxtype/config.toml";
    ".config/wezterm/wezterm.lua".source = mk "${dot}/wezterm-0-unstable-2025-05-18/.config/wezterm/wezterm.lua";
    ".git-templates".source = mk "${dot}/git-templates/.git-templates";
    ".gitconfig".source = mk "${dot}/git/.gitconfig";
    ".groovylintrc.json".source = mk "${dot}/groovy-lint/.groovylintrc.json";
    ".inputrc".source = mk "${dot}/readline/.inputrc";
    ".tmux.conf".source = mk "${dot}/tmux-3.5a/.tmux.conf";
    ".vim".source = mk "${dot}/vim-9.0/.vim";
    ".viminfo".source = mk "${dot}/vim-9.0/.viminfo";
    ".vimrc".source = mk "${dot}/vim-9.0/.vimrc";
    "dev/find-uncommitted.sh".source = mk "${dot}/dev/find-uncommitted.sh";
    "dev/grab.sh".source = mk "${dot}/dev/grab.sh";
    "dev/grab_parallel.sh".source = mk "${dot}/dev/grab_parallel.sh";
    "dev/save_cloned_repos.sh".source = mk "${dot}/dev/save_cloned_repos.sh";
    "dev/repos".source = mk "${dot}/dev/repos";
    ".local/bin/folder_stats".source = mk "${dot}/scripts/folder_stats";
    ".config/GIMP/3.0/".source = mk "${dot}/gimp-3.0/.config/GIMP/3.0";
    ".config/fastfetch/".source = mk "${dot}/fastfetch-2.58.0/.config/fastfetch";
    ".config/zigfetch/".source = mk "${dot}/zigfetch-0.25.0/.config/zigfetch";
  };

  home.sessionVariables = {};
}
