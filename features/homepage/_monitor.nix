{pkgs, ...}: let
  modules = pkgs.linkFarm "homepage-monitor-python" [
    {
      name = "openbao.py";
      path = ../../scripts/openbao.py;
    }
  ];
  monitor = pkgs.writeShellApplication {
    name = "homepage-monitor";
    runtimeInputs = [pkgs.python3 pkgs.bind.dnsutils pkgs.systemd];
    text = ''PYTHONPATH=${modules} exec python3 ${../../scripts/homepage-monitor.py} "$@"'';
  };
in {
  environment.systemPackages = [monitor];
  environment.etc."homepage-monitor/policy.hcl".source = ./policy.hcl;
  systemd = {
    services = {
      homepage-dashboard.serviceConfig.EnvironmentFile = ["-/run/homepage-monitor/credentials.env"];
      homepage-monitor = {
        description = "Refresh Homepage health summaries and its own OpenBao credentials";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${monitor}/bin/homepage-monitor collect";
          StateDirectory = "homepage-monitor";
          StateDirectoryMode = "0700";
          RuntimeDirectory = "homepage-monitor";
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = true;
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = ["/run/homepage-monitor" "/var/lib/homepage-monitor"];
          TimeoutStartSec = "90s";
        };
      };
      homepage-monitor-api = {
        description = "Serve fresh, sanitized Homepage health summaries on loopback";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = "${monitor}/bin/homepage-monitor serve";
          DynamicUser = true;
          Restart = "on-failure";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
          IPAddressDeny = "any";
          IPAddressAllow = "localhost";
        };
      };
    };
    timers.homepage-monitor = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "15s";
        OnUnitActiveSec = "60s";
      };
    };
  };
}
