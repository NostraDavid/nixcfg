{
  lib,
  local,
  stable,
  ...
}: let
  photogimpConfig = "${local.photogimp}/share/photogimp/GIMP/3.0";
in {
  home.packages = [
    stable.loupe # Image viewer and magnifier
    stable.mission-center # Task Manager for GNOME
    stable.mpv # Media player
    stable.pixelorama # Pixel art editor
    stable.qbittorrent-enhanced # BitTorrent client
    stable.qdirstat # Disk usage analyzer
    stable.spotify # Music streaming app
    stable.xnviewmp # Image viewer and converter
  ];

  home.activation.photogimpConfig =
    lib.hm.dag.entryAfter [
      "writeBoundary"
    ] ''
      target="$HOME/.config/GIMP/3.0"
      $DRY_RUN_CMD mkdir -p "$target"
      $DRY_RUN_CMD ${lib.getExe stable.rsync} -a --chmod=u+rwX ${photogimpConfig}/ "$target/"
    '';
}
