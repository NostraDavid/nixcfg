{
  config,
  repoRoot,
  ...
}: {
  home.file."Library/Application Support/Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/vscode-1.106.2/.config/Code/User/keybindings.json";
}
