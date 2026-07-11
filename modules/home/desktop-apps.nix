{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) attrNames filter listToAttrs map readDir;
  localPackageNames = let
    entries = readDir ../../pkgs;
  in
    filter (name: entries.${name} == "directory") (attrNames entries);
  local =
    listToAttrs
    (map (name: {
        inherit name;
        value = pkgs.${name};
      })
      localPackageNames);
  hasDlssUpdater = lib.elem local.dlss-updater config.home.packages;
in {
  home.packages = with pkgs; [
    fsearch
    geeqie
    ghostty
    gimp3
    gparted
    hardinfo2
    kdePackages.kclock
    keepassxc
    speedcrunch
    synology-drive-client
    wireguard-tools
  ];

  home.activation.dlssUpdaterCleanup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Never exit from activation snippets; that would abort later phases
    # (including linkGeneration) and leave managed files stale.
    if ${lib.getExe pkgs.flatpak} --user info io.github.recol.dlss-updater >/dev/null 2>&1; then
      if ! ${lib.boolToString hasDlssUpdater}; then
        ${lib.getExe pkgs.flatpak} --user uninstall -y io.github.recol.dlss-updater || true
      fi
    fi
  '';
}
