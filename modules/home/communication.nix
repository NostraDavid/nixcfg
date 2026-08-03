{pkgs, ...}: let
  stable = pkgs;
in {
  home.packages = [
    stable.evolution
    stable.legcord
    stable.signal-desktop
  ];
}
