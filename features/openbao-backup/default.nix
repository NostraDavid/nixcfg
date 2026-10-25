_: {
  den.aspects.openbao-backup.homeManager = {pkgs, ...}: let
    maintenance = pkgs.writeShellApplication {
      name = "openbao-maintain";
      runtimeInputs = [pkgs.python3 pkgs.age pkgs.openssh];
      text = ''exec python3 ${../../scripts/openbao-maintain.py} "$@"'';
    };
    service = command: {
      Unit = {
        Description = "OpenBao ${command}";
        OnFailure = ["openbao-alert.service"];
        ConditionPathExists = "%h/.local/state/nixcfg/openbao/enabled";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${maintenance}/bin/openbao-maintain ${command}";
        UMask = "0077";
      };
    };
    timer = calendar: {
      Install.WantedBy = ["timers.target"];
      Timer = {
        OnCalendar = calendar;
        Persistent = true;
        RandomizedDelaySec = "3m";
      };
    };
  in {
    home.packages = [maintenance];
    systemd.user.services = {
      openbao-backup = service "backup";
      openbao-tls = service "tls";
      openbao-watch = service "check";
      openbao-alert = {
        Unit.Description = "Report OpenBao rotation, health or backup failure";
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.libnotify}/bin/notify-send --urgency=critical OpenBao 'Vault maintenance failed. Check the OpenBao user service logs.'";
        };
      };
    };
    systemd.user.timers = {
      openbao-backup = timer "*-*-* *:10:00";
      openbao-tls = timer "*-*-01,15 03:00:00";
      openbao-watch = timer "*:0/5";
    };
  };
}
