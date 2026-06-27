{pkgs, ...}: {
  fileSystems = {
    "/var/lib/postgresql" = {
      device = "/dev/disk/by-label/apps-postgres";
      fsType = "ext4";
      options = ["nofail" "x-systemd.device-timeout=10s"];
    };

    "/srv/apps" = {
      device = "/dev/disk/by-label/apps-data";
      fsType = "ext4";
      options = ["nofail" "x-systemd.device-timeout=10s"];
    };
  };

  users = {
    groups = {
      huishoudboekje = {};
      recepten = {};
    };
    users = {
      huishoudboekje = {
        isSystemUser = true;
        group = "huishoudboekje";
        home = "/srv/apps/huishoudboekje";
      };
      recepten = {
        isSystemUser = true;
        group = "recepten";
        home = "/srv/apps/recepten";
      };
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d /srv/apps 0755 root root -"
      "d /srv/apps/huishoudboekje 0750 huishoudboekje huishoudboekje -"
      "d /srv/apps/huishoudboekje/data 0750 huishoudboekje huishoudboekje -"
      "d /srv/apps/recepten 0750 recepten recepten -"
      "d /srv/apps/recepten/data 0750 recepten recepten -"
      "d /opt/huishoudboekje 0755 root root -"
      "d /opt/recepten 0755 root root -"
    ];

    services = {
      huishoudboekje = {
        description = "Huishoudboekje web application";
        after = ["network-online.target" "postgresql.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionPathIsExecutable = "/opt/huishoudboekje/current/bin/huishoudboekje";
        environment = {
          HOST = "127.0.0.1";
          PORT = "3101";
          DATA_DIR = "/srv/apps/huishoudboekje/data";
          DATABASE_URL = "postgresql:///huishoudboekje?host=/run/postgresql";
        };
        serviceConfig = {
          User = "huishoudboekje";
          Group = "huishoudboekje";
          WorkingDirectory = "/srv/apps/huishoudboekje";
          ExecStart = "/opt/huishoudboekje/current/bin/huishoudboekje";
          Restart = "always";
          RestartSec = 5;
          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      };

      recepten = {
        description = "Recepten en boodschappen web application";
        after = ["network-online.target" "postgresql.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionPathIsExecutable = "/opt/recepten/current/bin/recepten";
        environment = {
          HOST = "127.0.0.1";
          PORT = "3102";
          DATA_DIR = "/srv/apps/recepten/data";
          DATABASE_URL = "postgresql:///recepten?host=/run/postgresql";
        };
        serviceConfig = {
          User = "recepten";
          Group = "recepten";
          WorkingDirectory = "/srv/apps/recepten";
          ExecStart = "/opt/recepten/current/bin/recepten";
          Restart = "always";
          RestartSec = 5;
          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      };
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [
      "huishoudboekje"
      "recepten"
    ];
    ensureUsers = [
      {
        name = "huishoudboekje";
        ensureDBOwnership = true;
      }
      {
        name = "recepten";
        ensureDBOwnership = true;
      }
    ];
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "huishoudboekje.home.arpa" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3101";
          proxyWebsockets = true;
        };
      };
      "recepten.home.arpa" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3102";
          proxyWebsockets = true;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [80];
}
