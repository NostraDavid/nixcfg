{
  lib,
  pkgs,
  ...
}: let
  root = "/srv/openbao";
  initializeDisk = pkgs.writeShellApplication {
    name = "openbao-initialize-disk";
    runtimeInputs = [pkgs.util-linux pkgs.e2fsprogs pkgs.diffutils pkgs.coreutils];
    text = builtins.readFile ../../scripts/lab-initialize-disk.sh;
  };
  ops = pkgs.writeShellApplication {
    name = "openbao-ops";
    runtimeInputs = [pkgs.python3 pkgs.openbao pkgs.age pkgs.openssl pkgs.openldap pkgs.systemd];
    text = ''exec python3 ${../../scripts/openbao.py} "$@"'';
  };
  mounted = {
    requires = ["srv-openbao.mount"];
    after = ["srv-openbao.mount"];
    unitConfig.AssertPathIsMountPoint = root;
  };
in {
  environment.systemPackages = [ops];
  users = {
    groups.openbao = {};
    users.openbao = {
      isSystemUser = true;
      group = "openbao";
    };
  };
  services = {
    openbao = {
      enable = true;
      settings = {
        ui = true;
        disable_mlock = true;
        audit = [
          {
            file.local = {
              description = "Persistent local audit log";
              options = {
                file_path = "${root}/audit/audit.json";
                log_raw = "false";
              };
            };
          }
        ];
        api_addr = "https://192.168.2.112";
        cluster_addr = "http://127.0.0.1:8201";
        listener.local = {
          type = "tcp";
          address = "127.0.0.1:8200";
          tls_disable = true;
          x_forwarded_for_authorized_addrs = ["127.0.0.1/32"];
          x_forwarded_for_reject_not_present = false;
        };
        storage.raft = {
          path = "${root}/raft";
          node_id = "openbao-01";
        };
        seal.static = {
          current_key_id = "local-1";
          current_key = "file://${root}/seal/key";
        };
      };
    };
    caddy = {
      enable = true;
      dataDir = "${root}/caddy";
      globalConfig = "skip_install_trust";
      virtualHosts."https://192.168.2.112" = {
        serverAliases = ["openbao.powerlan.empire" "secrets.powerlan.empire"];
        # OpenBao audits requests with HMAC; Caddy must not log its custom token header.
        logFormat = null;
        extraConfig = ''
          tls ${root}/tls/server.crt ${root}/tls/server.key
          reverse_proxy 127.0.0.1:8200
        '';
      };
    };
    logrotate.settings.openbao = {
      files = ["${root}/audit/audit.json"];
      frequency = "daily";
      rotate = 7;
      size = "50M";
      missingok = true;
      notifempty = true;
      compress = true;
      delaycompress = true;
      create = "0600 openbao openbao";
      postrotate = "${pkgs.systemd}/bin/systemctl kill --kill-whom=main --signal=HUP openbao.service";
    };
  };
  systemd.services = {
    openbao-data-init = {
      description = "Initialize only the designated empty OpenBao data disk";
      requiredBy = ["srv-openbao.mount"];
      before = ["srv-openbao.mount"];
      after = ["systemd-udev-trigger.service"];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "10min";
      };
      path = [pkgs.coreutils];
      script = ''
        for attempt in $(seq 1 15); do
          if [ -b /dev/disk/by-id/virtio-openbao-state ]; then
            exec ${initializeDisk}/bin/openbao-initialize-disk /dev/disk/by-id/virtio-openbao-state openbao-state
          fi
          sleep 1
        done
        echo 'Missing OpenBao data disk' >&2
        exit 1
      '';
    };
    openbao-prepare = lib.mkMerge [
      mounted
      {
        before = ["openbao.service" "caddy.service"];
        requiredBy = ["openbao.service" "caddy.service"];
        path = [pkgs.coreutils pkgs.openssl];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";
        };
        script = ''
          install -d -m 0711 ${root}
          install -d -m 0700 -o openbao -g openbao ${root}/{raft,seal,audit}
          install -d -m 0700 ${root}/{ops,backups}
          install -d -m 0750 -o root -g caddy ${root}/tls
          install -d -m 0700 -o caddy -g caddy ${root}/caddy
          if [ ! -s ${root}/seal/key ]; then
            if [ -e ${root}/raft/raft/raft.db ] || [ -e ${root}/ops/recovery.age ]; then
              echo 'Existing OpenBao state has no seal key; restore the original key' >&2
              exit 1
            fi
            openssl rand -out ${root}/seal/key.new 32
            chown openbao:openbao ${root}/seal/key.new
            chmod 0400 ${root}/seal/key.new
            mv ${root}/seal/key.new ${root}/seal/key
          fi
        '';
      }
    ];
    openbao = lib.mkMerge [
      mounted
      {
        requires = ["openbao-prepare.service"];
        after = ["openbao-prepare.service"];
        serviceConfig = {
          DynamicUser = lib.mkForce false;
          StateDirectory = lib.mkForce [];
          ProtectSystem = "strict";
          ReadWritePaths = ["${root}/raft" "${root}/audit"];
        };
      }
    ];
    caddy = lib.mkMerge [
      mounted
      {
        requires = ["openbao-prepare.service"];
        after = ["openbao-prepare.service"];
      }
    ];
    openbao-snapshot = lib.mkMerge [
      mounted
      {
        description = "Encrypt a consistent OpenBao snapshot and its recovery material";
        requires = ["openbao.service"];
        after = ["openbao.service"];
        unitConfig.ConditionPathExists = "${root}/ops/backup-credentials.json";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${ops}/bin/openbao-ops snapshot";
          UMask = "0077";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = ["${root}/backups"];
          RuntimeDirectory = "openbao-snapshot";
        };
      }
    ];
  };
  systemd.timers.openbao-snapshot = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "2m";
    };
  };
}
