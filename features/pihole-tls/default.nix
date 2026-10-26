_: {
  den.aspects.pihole-tls-server = {
    nixos = {pkgs, ...}: let
      bootstrap = pkgs.linkFarm "pihole-tls-bootstrap" [
        {
          name = "pihole-tls.py";
          path = ../../scripts/pihole-tls.py;
        }
        {
          name = "renew.service";
          path = ./renew.service;
        }
        {
          name = "renew.timer";
          path = ./renew.timer;
        }
        {
          name = "ca.crt";
          path = ../../certs/forgejo-ca.crt;
        }
      ];
    in {
      services.caddy.virtualHosts."https://192.168.2.113".extraConfig = ''
        handle /pihole-tls/* {
          header Cache-Control no-store
          root * /srv/certs/certificates
          file_server
        }
      '';
      systemd = {
        services = {
          pihole-tls-publish = {
            description = "Publish Pi-hole certificates using its fixed public request";
            after = ["caddy.service" "srv-certs.mount"];
            requires = ["srv-certs.mount"];
            unitConfig.AssertPathIsMountPoint = "/srv/certs";
            serviceConfig = {
              Type = "oneshot";
              UMask = "0077";
            };
            path = [pkgs.coreutils pkgs.openssl];
            script = ''
              install -d -m 0755 /srv/certs/certificates/pihole-tls
              for file in pihole-tls.py renew.service renew.timer ca.crt; do
                install -m 0644 ${bootstrap}/"$file" /srv/certs/certificates/pihole-tls/"$file"
              done
              exec ${pkgs.python3}/bin/python3 ${../../scripts/pihole-tls.py} publish --csr ${./request.csr}
            '';
          };
          pihole-tls-report = {
            description = "Publish the checked Pi-hole certificate status for Homepage";
            after = ["network-online.target" "caddy.service" "pihole-tls-publish.service"];
            wants = ["network-online.target"];
            requires = ["srv-certs.mount"];
            unitConfig.AssertPathIsMountPoint = "/srv/certs";
            path = [pkgs.openssl];
            serviceConfig = {
              Type = "oneshot";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = ["/srv/certs/certificates/pihole-tls"];
            };
            script = ''
              exec ${pkgs.python3}/bin/python3 ${../../scripts/pihole-tls.py} report --ca ${../../certs/forgejo-ca.crt}
            '';
          };
        };
        timers = {
          pihole-tls-publish = {
            wantedBy = ["timers.target"];
            timerConfig = {
              OnCalendar = "*-*-* 03:05:00";
              OnBootSec = "2min";
              Persistent = true;
              RandomizedDelaySec = "2min";
            };
          };
          pihole-tls-report = {
            wantedBy = ["timers.target"];
            timerConfig = {
              OnCalendar = "*:0/15";
              OnBootSec = "3min";
              Persistent = true;
              RandomizedDelaySec = "1min";
            };
          };
        };
      };
    };
  };
  den.aspects.pihole-tls = {
    homeManager = {pkgs, ...}: {
      systemd.user.services = {
        pihole-tls-watch = {
          Unit = {
            Description = "Check Pi-hole certificate renewal and HTTPS";
            OnFailure = ["pihole-tls-alert.service"];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/pihole-tls.py} check --ca ${../../certs/forgejo-ca.crt}";
            Environment = "PATH=${pkgs.lib.makeBinPath [pkgs.openssl]}";
          };
        };
        pihole-tls-alert = {
          Unit.Description = "Report a Pi-hole certificate renewal failure";
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.libnotify}/bin/notify-send --urgency=critical Pi-hole 'Certificaatvernieuwing of HTTPS-controle mislukt. Controleer Certificaten onder Beheer op home.powerlan.empire.'";
          };
        };
      };
      systemd.user.timers.pihole-tls-watch = {
        Install.WantedBy = ["timers.target"];
        Timer = {
          OnCalendar = "*:0/15";
          Persistent = true;
          RandomizedDelaySec = "1min";
        };
      };
    };
  };
}
