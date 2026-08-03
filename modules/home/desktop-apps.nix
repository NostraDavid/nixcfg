{pkgs, ...}: let
  stable = pkgs;
in {
  home.packages = [
    stable.fsearch
    stable.geeqie
    stable.gimp3
    stable.gparted
    stable.hardinfo2
    stable.kdePackages.kclock
    stable.keepassxc
    stable.speedcrunch
    stable.synology-drive-client
    stable.wireguard-tools
  ];
}
