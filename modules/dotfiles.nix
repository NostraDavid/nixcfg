# home/common.nix
# Shared home-manager configuration for all hosts.
{config, ...}: {
  # This list may look a little weird, but that's because the original dotfiles
  # were managed by `stow`, which needs this folder structure to work correctly.
  # I decided to keep it that way, so I could return to stow in the future.
  home.file = let
    dot = "${config.home.homeDirectory}/dev/NostraDavid/nixcfg/dotfiles";
    mk = path: config.lib.file.mkOutOfStoreSymlink path;
    forceAll = builtins.mapAttrs (_: file: file // {force = true;});
  in
    forceAll {
      ".bash_aliases" = {source = mk "${dot}/bash-5.2.37/.bash_aliases";};
      ".bash_profile" = {source = mk "${dot}/bash-5.2.37/.bash_profile";};
      ".bashrc" = {source = mk "${dot}/bash-5.2.37/.bashrc";};
      ".codex/AGENTS.md" = {source = mk "${dot}/codex-0.140.0/.codex/AGENTS.md";};
      ".codex/config.toml" = {source = mk "${dot}/codex-0.140.0/.codex/config.toml";};
      ".codex/rules/default.rules" = {source = mk "${dot}/codex-0.140.0/.codex/rules/default.rules";};
      ".codex/RTK.md" = {source = mk "${dot}/rtk-0.41.0/.codex/RTK.md";};
      ".codex/semble.md" = {source = mk "${dot}/semble-0.3.4/.codex/semble.md";};
      ".codex/snip.md" = {source = mk "${dot}/snip-0.18.0/.codex/snip.md";};
      ".config/clip-proxy/proxy-cli-policy.md" = {source = mk "${dot}/clip-proxy/.config/clip-proxy/proxy-cli-policy.md";};
      ".config/baloofilerc" = {source = mk "${dot}/baloo-6.20.0/.config/baloofilerc";};
      ".config/bat/config" = {source = mk "${dot}/bat-0.25.0/.config/bat/config";};
      ".config/Code/User/keybindings.json" = {source = mk "${dot}/vscode/.config/Code/User/keybindings.json";};
      ".config/Code/User/settings.json" = {source = mk "${dot}/vscode/.config/Code/User/settings.json";};
      ".config/fastfetch/" = {source = mk "${dot}/fastfetch-2.58.0/.config/fastfetch";};
      ".config/git/attributes" = {source = mk "${dot}/git/.config/git/attributes";};
      ".config/git/commit-template" = {source = mk "${dot}/git/.config/git/commit-template";};
      ".config/git/hooks" = {source = mk "${dot}/git/.config/git/hooks";};
      ".config/mpv/mpv.conf" = {source = mk "${dot}/mpv/.config/mpv/mpv.conf";};
      ".config/nvim/" = {source = mk "${dot}/neovim-0.11/.config/nvim";};
      ".config/pip/pip.conf" = {source = mk "${dot}/pip-22+/.config/pip/pip.conf";};
      ".config/powerline" = {source = mk "${dot}/powerline-bash/.config/powerline";};
      ".config/pypoetry/" = {source = mk "${dot}/pypoetry-2.1/.config/pypoetry";};
      ".config/RSS Guard 4/config/config.ini" = {source = mk "${dot}/rssguard-4/.config/RSS Guard 4/config/config.ini";};
      ".config/snip/filters" = {source = mk "${dot}/snip-0.18.0/.config/snip/filters";};
      ".config/starship.toml" = {source = mk "${dot}/starship-1.23.0/.config/starship.toml";};
      ".config/wezterm/wezterm.lua" = {source = mk "${dot}/wezterm-0-unstable-2025-05-18/.config/wezterm/wezterm.lua";};
      ".config/zigfetch/" = {source = mk "${dot}/zigfetch-0.25.0/.config/zigfetch";};
      ".git-templates" = {source = mk "${dot}/git-templates/.git-templates";};
      ".gitconfig" = {source = mk "${dot}/git/.gitconfig";};
      ".github/copilot-instructions.md" = {source = mk "${dot}/clip-proxy/.config/clip-proxy/proxy-cli-policy.md";};
      ".groovylintrc.json" = {source = mk "${dot}/groovy-lint/.groovylintrc.json";};
      ".inputrc" = {source = mk "${dot}/readline/.inputrc";};
      ".local/bin/folder_stats" = {source = mk "${dot}/scripts/folder_stats";};
      ".tmux.conf" = {source = mk "${dot}/tmux-3.5a/.tmux.conf";};
      ".vim" = {source = mk "${dot}/vim-9.0/.vim";};
      ".vimrc" = {source = mk "${dot}/vim-9.0/.vimrc";};
      "dev/find-uncommitted.py" = {source = mk "${dot}/dev/find-uncommitted.py";};
      "dev/grab.py" = {source = mk "${dot}/dev/grab.py";};
      "dev/repos.dat" = {source = mk "${dot}/dev/repos.dat";};
      "dev/save_cloned_repos.py" = {source = mk "${dot}/dev/save_cloned_repos.py";};
      "rsync-bitvavo" = {source = mk "${dot}/scripts/rsync-bitvavo";};
      # ".config/voxtype/config.toml" = {source = mk "${dot}/voxtype/.config/voxtype/config.toml";};
    };

  home.sessionVariables = {};
}
