{pkgs, ...}: {
  services.xserver.xkb.extraLayouts.runic = {
    description = "Custom Runic Keyboard Layout";
    languages = ["run"];
    symbolsFile = "${pkgs.runic}/share/X11/xkb/symbols/runic";
  };
}
