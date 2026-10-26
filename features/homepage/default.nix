_: {
  den.aspects.homepage.nixos = {pkgs, ...}: let
    health = mappings: {
      type = "customapi";
      url = "http://127.0.0.1:3001/status.json";
      refreshInterval = 30000;
      inherit mappings;
    };
    tls = name:
      health [
        {
          field = "certificates.${name}.status";
          label = "HTTPS";
        }
        {
          field = "certificates.${name}.days";
          label = "Dagen geldig";
        }
      ];
  in {
    imports = [./_monitor.nix];
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
                icon = "/icons/proxmox.svg";
                href = "https://proxmox.powerlan.empire/";
                description = "POwerMonolith · virtuele machines en opslag";
                siteMonitor = "https://proxmox.powerlan.empire/";
                widgets = [
                  {
                    type = "proxmox";
                    url = "https://proxmox.powerlan.empire";
                    username = "{{HOMEPAGE_VAR_PROXMOX_USER}}";
                    password = "{{HOMEPAGE_VAR_PROXMOX_TOKEN}}";
                    node = "POwerMonolith";
                    fields = ["vms" "resources.cpu" "resources.mem"];
                  }
                  (tls "proxmox")
                ];
              };
            }
            {
              "Pi-hole" = {
                icon = "/icons/pi-hole.svg";
                href = "https://pihole.powerlan.empire/admin/";
                description = "DNS en netwerkfiltering";
                siteMonitor = "https://pihole.powerlan.empire/admin/";
                widgets = [
                  {
                    type = "pihole";
                    url = "https://pihole.powerlan.empire";
                    version = 6;
                    key = "{{HOMEPAGE_VAR_PIHOLE_KEY}}";
                    fields = ["queries" "blocked" "blocked_percent"];
                  }
                  (health [
                    {
                      field = "dns.status";
                      label = "DNS-query";
                    }
                    {
                      field = "certificates.pihole.status";
                      label = "HTTPS";
                    }
                    {
                      field = "certificates.pihole.days";
                      label = "Dagen geldig";
                    }
                  ])
                ];
              };
            }
            {
              FreeIPA = {
                icon = "/icons/freeipa.svg";
                href = "https://ldap.powerlan.empire/ipa/ui/";
                description = "Accounts, groepen en aanmeldingen";
                siteMonitor = "https://ldap.powerlan.empire/ipa/ui/";
                widgets = [
                  (health [
                    {
                      field = "ldap.status";
                      label = "LDAP-aanmeldingen";
                    }
                    {
                      field = "ldap.last";
                      label = "Laatste controle";
                      format = "relativeDate";
                      locale = "nl";
                    }
                  ])
                  (tls "freeipa")
                ];
              };
            }
          ];
        }
        {
          Diensten = [
            {
              Forgejo = {
                icon = "/icons/forgejo.svg";
                href = "https://forgejo.powerlan.empire/";
                description = "Git-repositories en samenwerking";
                siteMonitor = "https://forgejo.powerlan.empire/";
                widget = tls "forgejo";
              };
            }
            {
              OpenBao = {
                icon = "/icons/openbao.svg";
                href = "https://openbao.powerlan.empire/";
                description = "Servicegeheimen en wachtwoordrotatie";
                siteMonitor = "https://openbao.powerlan.empire/v1/sys/health";
                widgets = [
                  (tls "openbao")
                  (health [
                    {
                      field = "rotation.status";
                      label = "Wachtwoordrotatie";
                    }
                    {
                      field = "rotation.last";
                      label = "Oudste rotatie";
                      format = "relativeDate";
                      locale = "nl";
                    }
                  ])
                ];
              };
            }
            {
              "Home Assistant" = {
                icon = "/icons/home-assistant.svg";
                href = "https://homeassistant.powerlan.empire/";
                description = "Slimme woning en automatisering";
                siteMonitor = "https://homeassistant.powerlan.empire/";
                widget = tls "homeassistant";
              };
            }
          ];
        }
        {
          Beheer = [
            {
              "Kluisback-up" = {
                icon = "/icons/openbao.svg";
                href = "https://openbao.powerlan.empire/";
                description = "Versleutelde herstelkopie buiten Proxmox op Wodan";
                widget = health [
                  {
                    field = "backup.status";
                    label = "Back-up";
                  }
                  {
                    field = "backup.last";
                    label = "Laatste succes";
                    format = "relativeDate";
                    locale = "nl";
                  }
                  {
                    field = "credentials.status";
                    label = "Kluisverbinding";
                  }
                ];
              };
            }
            {
              Certificaten = {
                icon = "/icons/certificate.svg";
                href = "https://certs.powerlan.empire/";
                description = "Certificaatdownloads en Pi-hole HTTPS";
                siteMonitor = "https://certs.powerlan.empire/";
                widgets = [
                  (tls "certs")
                  (health [
                    {
                      field = "certificates.home.status";
                      label = "Homepage HTTPS";
                    }
                    {
                      field = "certificates.home.days";
                      label = "Homepage dagen";
                    }
                  ])
                  {
                    type = "customapi";
                    url = "https://certs.powerlan.empire/pihole-tls/status.json";
                    refreshInterval = 60000;
                    mappings = [
                      {
                        field = "status";
                        label = "Pi-hole vernieuwing";
                      }
                      {
                        field = "checked";
                        label = "Controle";
                        format = "relativeDate";
                        locale = "nl";
                      }
                    ];
                  }
                ];
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
