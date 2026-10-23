{
  config,
  lib,
  repoRoot,
  stable,
  ...
}: let
  darwin = stable.stdenv.hostPlatform.isDarwin;
  plocate =
    if darwin
    then stable.callPackage ../../pkgs/plocate-xnu {}
    else stable.plocate;
  directory = "${config.xdg.cacheHome}/plocate";
  database = "${directory}/plocate.db";
  configFile = "${config.xdg.configHome}/plocate/updatedb.conf";
  update = stable.writeShellScript "updatedb" ''
    set -eu
    umask 077
    ${stable.coreutils}/bin/mkdir -p ${lib.escapeShellArg directory}
    ${stable.coreutils}/bin/chmod 0700 ${lib.escapeShellArg directory}
    # The macOS fork predates --config-file, so use its per-user config override.
    ${lib.optionalString darwin "export PLOCATE_UPDATEDB_CONF=${lib.escapeShellArg configFile}"}
    ${lib.optionalString (!darwin) "set -- --config-file=${lib.escapeShellArg configFile} \"$@\""}
    exec ${plocate}/bin/updatedb \
      --output=${lib.escapeShellArg database} --require-visibility=no "$@"
  '';
  query = stable.writeShellScript "plocate" ''
    exec ${plocate}/bin/plocate --database=${lib.escapeShellArg database} "$@"
  '';
  commands = stable.runCommand "plocate-user-commands" {} ''
    mkdir -p "$out/bin"
    ln -s ${update} "$out/bin/updatedb"
    ln -s ${query} "$out/bin/plocate"
    ln -s ${query} "$out/bin/locate"
  '';
in {
  home = {
    packages = [plocate (lib.hiPrio commands)];
    file =
      lib.genAttrs [".local/bin/updatedb" ".local/bin/plocate" ".local/bin/locate"]
      (path: {source = "${commands}/bin/${builtins.baseNameOf path}";});
    sessionPath = ["${config.home.homeDirectory}/.local/bin"];
  };
  xdg.configFile."plocate/updatedb.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/plocate/.config/plocate/updatedb.conf";

  systemd.user = lib.mkIf (!darwin) {
    services.plocate = {
      Unit.Description = "Update the user's plocate database";
      Service = {
        Type = "oneshot";
        ExecStart = toString update;
      };
    };
    timers.plocate = {
      Unit.Description = "Update the user's plocate database daily";
      Timer = {
        OnCalendar = "*-*-* 03:15:00";
        OnStartupSec = "5m";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
  launchd.agents.plocate = lib.mkIf darwin {
    enable = true;
    config = {
      ProgramArguments = ["${update}"];
      ProcessType = "Background";
      RunAtLoad = true;
      StartCalendarInterval = [
        {
          Hour = 3;
          Minute = 15;
        }
      ];
    };
  };
}
