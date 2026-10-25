{pkgs, ...}: let
  state = "/srv/forgejo/openbao-consumer";
  settings = pkgs.writeText "forgejo-openbao.json" (builtins.toJSON {
    service = "forgejo-reader";
    address = "https://192.168.2.112";
    forgejo_configure = "${../../scripts/forgejo-ldap-configure.sh}";
  });
in {
  systemd.services.openbao-consumer = {
    description = "Reconcile the current OpenBao LDAP credential into Forgejo";
    requires = ["srv-forgejo.mount"];
    wants = ["forgejo.service" "network-online.target"];
    after = ["srv-forgejo.mount" "forgejo.service" "network-online.target"];
    unitConfig = {
      AssertPathIsMountPoint = "/srv/forgejo";
      ConditionPathExists = "${state}/credentials.json";
    };
    path = [pkgs.python3 pkgs.openldap pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gawk pkgs.systemd pkgs.curl];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/openbao.py} consume --config ${settings} --state ${state}";
      UMask = "0077";
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = ["/srv/forgejo"];
      TimeoutStartSec = "3min";
    };
  };
  systemd.timers.openbao-consumer = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "90s";
      OnUnitInactiveSec = "1min";
    };
  };
}
