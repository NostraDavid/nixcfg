{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.forgejo;
  initializeDisk = pkgs.writeShellApplication {
    name = "forgejo-initialize-disk";
    runtimeInputs = [pkgs.util-linux pkgs.e2fsprogs pkgs.diffutils pkgs.coreutils];
    text = builtins.readFile ../cmd/lab-initialize-disk.sh;
  };
  forgejo = "${config.services.forgejo.package}/bin/forgejo --work-path /srv/forgejo/forgejo --config /srv/forgejo/forgejo/custom/conf/app.ini";
  requireData = {
    requires = ["srv-forgejo.mount"];
    after = ["srv-forgejo.mount"];
    unitConfig.AssertPathIsMountPoint = "/srv/forgejo";
  };
in {
  options.lab.forgejo = {
    enable = lib.mkEnableOption "the Forgejo service with a separate persistent disk";
    address = lib.mkOption {type = lib.types.str;};
    dataDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/disk/by-id/virtio-forgejo-state";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/srv/forgejo" = {
      device = "/dev/disk/by-label/forgejo-state";
      fsType = "ext4";
      options = ["nofail" "x-systemd.device-timeout=11min"];
    };

    services = {
      forgejo = {
        enable = true;
        package = pkgs.forgejo-lts;
        useWizard = false;
        stateDir = "/srv/forgejo/forgejo";
        database.type = "postgres";
        settings = {
          DEFAULT.APP_NAME = "Forgejo lab";
          server = {
            DOMAIN = cfg.address;
            ROOT_URL = "http://${cfg.address}:3000/";
            HTTP_ADDR = "0.0.0.0";
            START_SSH_SERVER = true;
            SSH_DOMAIN = cfg.address;
            SSH_PORT = 2222;
            SSH_LISTEN_PORT = 2222;
          };
          service.DISABLE_REGISTRATION = true;
          actions.ENABLED = false;
        };
      };
      postgresql = {
        package = pkgs.postgresql_16;
        dataDir = "/srv/forgejo/postgresql/16";
      };
    };

    systemd.services = {
      forgejo-data-init = {
        description = "Initialize only the designated, zero-filled Forgejo data disk";
        requiredBy = ["srv-forgejo.mount"];
        before = ["srv-forgejo.mount"];
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
            if [ -b '${cfg.dataDevice}' ]; then
              exec ${initializeDisk}/bin/forgejo-initialize-disk '${cfg.dataDevice}' forgejo-state
            fi
            sleep 1
          done
          echo 'Missing Forgejo data disk: ${cfg.dataDevice}' >&2
          exit 1
        '';
      };

      forgejo-data-directories = lib.mkMerge [
        requireData
        {
          description = "Create service directories only on the mounted data disk";
          requiredBy = ["postgresql.service" "forgejo-secrets.service" "forgejo.service"];
          before = ["postgresql.service" "forgejo-secrets.service" "forgejo.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [pkgs.coreutils];
          script = ''
            install -d -m 0750 -o postgres -g postgres /srv/forgejo/postgresql
            install -d -m 0700 -o postgres -g postgres /srv/forgejo/postgresql/16
            ${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=/srv/forgejo
          '';
        }
      ];

      postgresql = requireData;
      forgejo = requireData;
      forgejo-secrets = requireData;
      forgejo-admin = lib.mkMerge [
        requireData
        {
          description = "Create the initial lab administrator without resetting existing accounts";
          wantedBy = ["multi-user.target"];
          requires = ["forgejo.service"];
          after = ["forgejo.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";
          };
          path = [pkgs.curl pkgs.coreutils pkgs.openssl pkgs.util-linux config.services.postgresql.package];
          script = ''
            for attempt in $(seq 1 120); do
              if curl --fail --silent http://127.0.0.1:3000/api/healthz >/dev/null; then break; fi
              sleep 1
            done
            curl --fail --silent http://127.0.0.1:3000/api/healthz >/dev/null
            count=$(runuser -u postgres -- psql forgejo -Atc "SELECT count(*) FROM \"user\" WHERE lower_name = 'david';")
            if [ "$count" != 0 ]; then exit 0; fi
            if [ ! -s /srv/forgejo/admin-password ]; then
              openssl rand -base64 24 > /srv/forgejo/admin-password
            fi
            runuser -u forgejo -- ${forgejo} admin user create \
              --username david --email david@forgejo-lab.home.arpa \
              --password "$(cat /srv/forgejo/admin-password)" \
              --admin --must-change-password=false >/dev/null
          '';
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [3000 2222];
  };
}
