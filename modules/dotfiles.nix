# home/common.nix
# Shared home-manager configuration for all hosts.
{pkgs, ...}: {
  # This list may look a little weird, but that's because the original dotfiles
  # were managed by `stow`, which needs this folder structure to work correctly.
  # I decided to keep it that way, so I could return to stow in the future.
  home.file = {
    ".bash_aliases".source = ../dotfiles/bash-5.2.37/.bash_aliases;
    ".bash_profile".source = ../dotfiles/bash-5.2.37/.bash_profile;
    ".bashrc".source = ../dotfiles/bash-5.2.37/.bashrc;
    ".config/bat/config".source = ../dotfiles/bat-0.25.0/.config/bat/config;
    ".config/neovim/" = {
      source = ../dotfiles/neovim-0.11/.config/neovim;
      recursive = true;
    };
    ".config/pip/pip.conf".source = ../dotfiles/pip-22+/.config/pip/pip.conf;
    ".config/powerline" = {
      source = ../dotfiles/powerline-bash/.config/powerline;
      recursive = true;
    };
    ".config/pypoetry/" = {
      source = ../dotfiles/pypoetry-2.1/.config/pypoetry;
      recursive = true;
    };
    ".config/pypoetry/config.toml".source = ../dotfiles/pypoetry-2.1/.config/pypoetry/config.toml;
    ".config/starship.toml".source = ../dotfiles/starship-1.23.0/.config/starship.toml;
    ".config/wezterm/wezterm.lua".source = ../dotfiles/wezterm-0-unstable-2025-05-18/.config/wezterm/wezterm.lua;
    ".git-templates" = {
      source = ../dotfiles/git-templates/.git-templates;
      recursive = true;
    };
    ".gitconfig".source = ../dotfiles/git/.gitconfig;
    ".groovylintrc.json".source = ../dotfiles/groovy-lint/.groovylintrc.json;
    ".inputrc".source = ../dotfiles/readline/.inputrc;
    ".tmux.conf".source = ../dotfiles/tmux-3.5a/.tmux.conf;
    ".vim" = {
      source = ../dotfiles/vim-9.0/.vim;
      recursive = true;
    };
    ".viminfo".source = ../dotfiles/vim-9.0/.viminfo;
    ".vimrc".source = ../dotfiles/vim-9.0/.vimrc;
    "dev/find-uncommitted.sh".source = ../dotfiles/dev/find-uncommitted.sh;
    "dev/grab.sh".source = ../dotfiles/dev/grab.sh;
    "dev/grab_parallel.sh".source = ../dotfiles/dev/grab_parallel.sh;
    ".local/bin/folder_stats".source = ../dotfiles/scripts/folder_stats;
  };

  home.sessionVariables = {};
}
