{pkgs, ...}: let
  local = {inherit (pkgs) runic;};
in {
  services.xserver.xkb.extraLayouts.runic = {
    description = "Custom Runic Keyboard Layout";
    languages = ["run"];
    symbolsFile = "${local.runic}/share/X11/xkb/symbols/runic";
  };
}
