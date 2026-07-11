{pkgs, ...}: {
  home.packages = with pkgs; [
    evolution
    legcord
    signal-desktop
  ];
}
