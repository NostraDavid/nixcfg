{pkgs, ...}: {
  home.packages = with pkgs; [
    libreoffice-qt6
    wireguard-ui
  ];
}
