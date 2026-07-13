{pkgs, ...}: {
  home.packages = with pkgs; [
    fsearch
    geeqie
    ghostty
    gimp3
    gparted
    hardinfo2
    hermes-agent-desktop
    kdePackages.kclock
    keepassxc
    speedcrunch
    synology-drive-client
    wireguard-tools
  ];
}
