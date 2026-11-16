{
  config,
  pkgs,
  ...
}: let
  state = "/srv/nextcloud/openbao-consumer";
  settings = pkgs.writeText "nextcloud-openbao.json" (builtins.toJSON {
    service = "nextcloud-reader";
    address = "https://192.168.2.112";
  });
in {
  systemd.services.openbao-consumer = {
    description = "Reconcile the current OpenBao LDAP credential into Nextcloud";
    requires = ["srv-nextcloud.mount"];
    wants = ["nextcloud-setup.service" "network-online.target"];
    after = ["srv-nextcloud.mount" "nextcloud-setup.service" "network-online.target"];
    unitConfig = {
      AssertPathIsMountPoint = "/srv/nextcloud";
      ConditionPathExists = "${state}/credentials.json";
    };
    path = [pkgs.python3 pkgs.openldap pkgs.util-linux pkgs.coreutils pkgs.systemd config.services.nextcloud.occ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/openbao.py} consume --config ${settings} --state ${state}";
      UMask = "0077";
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = ["/srv/nextcloud"];
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
