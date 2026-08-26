{
  local,
  stable,
  ...
}: {
  home.packages = [
    stable.fsearch # Everything-like file search tool
    stable.geeqie # Image viewer
    stable.gparted # Partition editor
    stable.gramps # Genealogy application
    stable.hardinfo2 # System profiler and benchmark
    stable.kdePackages.kclock # Stopwatch and clock
    stable.keepassxc # Password manager
    local.linear-linux # Unofficial Linear desktop client
    stable.meld # Graphical file and directory comparison
    stable.nomacs # Image viewer
    stable.speedcrunch # calculator
    stable.synology-drive-client # Synology Drive client
    stable.wireguard-tools # self-hosted VPN
  ];
}
