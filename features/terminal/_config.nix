# Shell, prompt, TUI, and terminal-emulator configuration.
{
  config,
  repoRoot,
  stable,
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
      ".bashrc.d" = {source = mk "${dot}/bash-5.2.37/bashrc.d";};
      ".config/alacritty/alacritty.toml" = {source = mk "${dot}/alacritty-0.17.0/.config/alacritty/alacritty.toml";};
      ".config/bat/config" = {source = mk "${dot}/bat-0.25.0/.config/bat/config";};
      ".config/btop/btop.conf" = {source = mk "${dot}/btop-1.4.7/btop.conf";};
      ".config/fastfetch/" = {source = mk "${dot}/fastfetch-2.58.0/.config/fastfetch";};
      ".config/ghostty/config.ghostty" = {source = mk "${dot}/ghostty-1.3.1/.config/ghostty/config.ghostty";};
      ".config/kitty/kitty.conf" = {source = mk "${dot}/kitty-0.49.1/.config/kitty/kitty.conf";};
      ".config/starship.toml" = {source = mk "${dot}/starship-1.23.0/.config/starship.toml";};
      ".config/wezterm/wezterm.lua" = {source = mk "${dot}/wezterm-0-unstable-2025-05-18/.config/wezterm/wezterm.lua";};
      ".config/zellij/config.kdl" = {source = mk "${dot}/zellij-0.45.1/.config/zellij/config.kdl";};
      ".config/zigfetch/" = {source = mk "${dot}/zigfetch-0.25.0/.config/zigfetch";};
      ".inputrc" = {source = mk "${dot}/readline-8.2p13/.inputrc";};
      ".local/bin/nix-bash".source = "${stable.bashInteractive}/bin/bash";
      ".tmux.conf" = {source = mk "${dot}/tmux-3.5a/.tmux.conf";};
    };
}
