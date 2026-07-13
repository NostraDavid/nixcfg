# Shell, prompt, TUI, and terminal-emulator configuration.
{
  config,
  repoRoot,
  ...
}: {
  home.file = let
    dot = "${repoRoot}/dotfiles";
    mk = path: config.lib.file.mkOutOfStoreSymlink path;
    forceAll = builtins.mapAttrs (_: file: file // {force = true;});
  in
    forceAll {
      ".bash_aliases" = {source = mk "${dot}/bash-5.2.37/.bash_aliases";};
      ".bash_profile" = {source = mk "${dot}/bash-5.2.37/.bash_profile";};
      ".bashrc" = {source = mk "${dot}/bash-5.2.37/.bashrc";};
      ".config/bat/config" = {source = mk "${dot}/bat-0.25.0/.config/bat/config";};
      ".config/btop/btop.conf" = {source = mk "${dot}/btop/btop.conf";};
      ".config/fastfetch/" = {source = mk "${dot}/fastfetch-2.58.0/.config/fastfetch";};
      ".config/ghostty/config.ghostty" = {source = mk "${dot}/ghostty-1.3.1/.config/ghostty/config.ghostty";};
      ".config/starship.toml" = {source = mk "${dot}/starship-1.23.0/.config/starship.toml";};
      ".config/wezterm/wezterm.lua" = {source = mk "${dot}/wezterm-0-unstable-2025-05-18/.config/wezterm/wezterm.lua";};
      ".config/zigfetch/" = {source = mk "${dot}/zigfetch-0.25.0/.config/zigfetch";};
      ".inputrc" = {source = mk "${dot}/readline/.inputrc";};
      ".tmux.conf" = {source = mk "${dot}/tmux-3.5a/.tmux.conf";};
    };
}
