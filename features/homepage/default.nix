_: {
  den.aspects.homepage.nixos = {pkgs, ...}: {
    services.homepage-dashboard = {
      enable = true;
      listenPort = 3000;
      allowedHosts = "home.powerlan.empire,localhost:3000,127.0.0.1:3000";
      customJS = builtins.readFile ./rfc3339-clock.js;
      settings = {
        title = "PowerLAN";
        description = "Diensten en beheer van PowerLAN";
        language = "nl";
        theme = "dark";
        color = "slate";
        target = "_blank";
        headerStyle = "clean";
        statusStyle = "dot";
        disableUpdateCheck = true;
        quicklaunch = {
          searchDescriptions = true;
          hideInternetSearch = true;
        };
      };
      widgets = [
        {
          resources = {
            label = "Homepage";
            cpu = true;
            memory = true;
            uptime = true;
          };
        }
        {
          datetime = {
            locale = "sv-SE";
            text_size = "xl";
            format = {
              year = "numeric";
              month = "2-digit";
              day = "2-digit";
              hour = "2-digit";
              minute = "2-digit";
              second = "2-digit";
              hourCycle = "h23";
              timeZoneName = "longOffset";
              timeZone = "Europe/Amsterdam";
            };
          };
        }
      ];
      services = [
        {
          Infrastructuur = [
            {
              Proxmox = {
                icon = "proxmox.svg";
                href = "https://proxmox.powerlan.empire/";
                description = "POwerMonolith · virtuele machines en opslag";
                siteMonitor = "https://proxmox.powerlan.empire/";
              };
            }
            {
              "Pi-hole" = {
                icon = "pi-hole.svg";
                href = "https://pihole.powerlan.empire/admin/";
                description = "DNS en netwerkfiltering";
                siteMonitor = "https://pihole.powerlan.empire/admin/";
              };
            }
            {
              FreeIPA = {
                icon = "freeipa.svg";
                href = "https://ldap.powerlan.empire/ipa/ui/";
                description = "Accounts, groepen en aanmeldingen";
                siteMonitor = "https://ldap.powerlan.empire/ipa/ui/";
              };
            }
          ];
        }
        {
          Diensten = [
            {
              Forgejo = {
                icon = "forgejo.svg";
                href = "https://forgejo.powerlan.empire/";
                description = "Git-repositories en samenwerking";
                siteMonitor = "https://forgejo.powerlan.empire/";
              };
            }
            {
              OpenBao = {
                icon = "openbao.svg";
                href = "https://openbao.powerlan.empire/";
                description = "Servicegeheimen en wachtwoordrotatie";
                siteMonitor = "https://openbao.powerlan.empire/v1/sys/health";
              };
            }
            {
              "Home Assistant" = {
                icon = "home-assistant.svg";
                href = "https://homeassistant.powerlan.empire/";
                description = "Slimme woning en automatisering";
                siteMonitor = "https://homeassistant.powerlan.empire/";
              };
            }
          ];
        }
        {
          Beheer = [
            {
              Certificaten = {
                icon = "mdi-certificate-outline";
                href = "https://certs.powerlan.empire/";
                description = "Certificaatdownloads en Pi-hole HTTPS";
                siteMonitor = "https://certs.powerlan.empire/";
                widget = {
                  type = "customapi";
                  url = "https://certs.powerlan.empire/pihole-tls/status.json";
                  refreshInterval = 60000;
                  mappings = [
                    {
                      field = "status";
                      label = "Pi-hole HTTPS";
                    }
                    {
                      field = "days";
                      label = "Dagen geldig";
                    }
                    {
                      field = "checked";
                      label = "Controle";
                      format = "relativeDate";
                      locale = "nl";
                    }
                  ];
                };
              };
            }
          ];
        }
      ];
    };

    # Node must use the host's filtered public roots and internal CA certificates.
    systemd.services.homepage-dashboard.environment = {
      HOSTNAME = "0.0.0.0";
      NODE_OPTIONS = "--use-openssl-ca";
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      SSL_CERT_DIR = "${pkgs.emptyDirectory}";
    };
    security.pki.certificateFiles = [../../hosts/physical/wodan/certs/proxmox.crt];
  };
}
