{local, ...}: {
  services.xserver.xkb.extraLayouts.runic = {
    description = "Custom Runic Keyboard Layout";
    languages = ["run"];
    symbolsFile = "${local.runic}/share/X11/xkb/symbols/runic";
  };
}
