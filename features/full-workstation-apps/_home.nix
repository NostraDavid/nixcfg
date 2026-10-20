{
  local,
  stable,
  ...
}: {
  imports = [./_taskbar.nix];

  home.packages = [
    local.chatgpt # Official ChatGPT desktop application
    stable.libreoffice-qt6 # Full office suite for primary workstations
    stable.wireguard-ui # Graphical WireGuard administration
  ];
}
