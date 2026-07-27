{
  lib,
  pkgs,
  ...
}: let
  stable = pkgs;
  dpaintJsPort = 18087;
  inherit (builtins) attrNames filter listToAttrs map readDir;
  localPackageNames = let
    entries = readDir ../../pkgs;
  in
    filter (name: entries.${name} == "directory") (attrNames entries);
  local =
    listToAttrs
    (map (name: {
        inherit name;
        value = stable.${name};
      })
      localPackageNames);
  photogimpConfig = "${local.photogimp}/share/photogimp/GIMP/3.0";
in {
  home.packages = [
    stable.loupe
    stable.mission-center
    stable.mpv
    stable.pixelorama
    stable.qbittorrent-enhanced
    stable.qdirstat
    stable.rssguard
    stable.spotify
    stable.xnviewmp
  ];

  home.activation.photogimpConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    target="$HOME/.config/GIMP/3.0"
    $DRY_RUN_CMD mkdir -p "$target"
    $DRY_RUN_CMD ${lib.getExe stable.rsync} -a --chmod=u+rwX ${photogimpConfig}/ "$target/"
  '';

  systemd.user.services.dpaint-js = {
    Unit = {
      Description = "DPaint.js local web server";
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${lib.getExe stable.python3} -m http.server ${toString dpaintJsPort} --bind 127.0.0.1 --directory ${local.dpaint-js}/share/dpaint-js";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["default.target"];
  };
}
