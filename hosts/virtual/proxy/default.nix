{
  den,
  constructors,
  ...
}: {
  den.hosts.x86_64-linux.proxy = {
    aspect = den.aspects.host-proxy;
    instantiate = constructors.nixos {
      hostname = "proxy";
    };
  };

  den.aspects.host-proxy = {
    includes = with den.aspects; [
      proxmox-guest
    ];
    nixos = {
      lib,
      main-user,
      pkgs,
      ...
    }: let
      initializeDisk = pkgs.writeShellApplication {
        name = "proxy-initialize-disk";
        runtimeInputs = [
          pkgs.util-linux
          pkgs.e2fsprogs
          pkgs.diffutils
          pkgs.coreutils
        ];
        text = builtins.readFile ../../../scripts/lab-initialize-disk.sh;
      };
      backendCaCert = "/srv/proxy/backend-root.crt";
      acmeTls = ''
        tls {
          issuer acme {
            dir https://192.168.2.113:8443/acme/local/directory
            trusted_roots ${../../../certs/forgejo-ca.crt}
          }
        }
      '';
      certificateSiteConfig = ''
        reverse_proxy https://192.168.2.113 {
          transport http {
            tls_trust_pool file ${../../../certs/forgejo-ca.crt}
          }
        }
      '';
    in {
      environment.systemPackages = [pkgs.openssl];
      networking = {
        hostName = "proxy";
        useDHCP = false;
        interfaces.ens18.ipv4.addresses = [
          {
            address = "192.168.2.111";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.2.1";
        nameservers = [
          "192.168.2.102"
        ];
        firewall.allowedTCPPorts = [
          2222
        ];
      };
      fileSystems = {
        "/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        "/srv/proxy" = {
          device = "/dev/disk/by-label/proxy-state";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.device-timeout=11min"
          ];
        };
      };
      boot = {
        loader.grub.device = lib.mkForce "/dev/vda";
        initrd.availableKernelModules = [
          "virtio_blk"
        ];
        kernelParams = [
          "console=ttyS0"
        ];
      };
      services = {
        qemuGuest.enable = true;
        caddy = {
          enable = true;
          dataDir = "/srv/proxy/caddy-acme";
          globalConfig = "skip_install_trust";
          virtualHosts = {
            "http://192.168.2.111".extraConfig = certificateSiteConfig;
            "https://192.168.2.111".extraConfig = acmeTls + certificateSiteConfig;
            "poc.apps.powerlan.empire".extraConfig =
              acmeTls
              + ''
                reverse_proxy 192.168.2.106:8080
              '';
            "ctb.apps.powerlan.empire".extraConfig =
              acmeTls
              + ''
                reverse_proxy 192.168.2.106:8080
              '';
            "huishoudboekje.apps.powerlan.empire".extraConfig =
              acmeTls
              + ''
                reverse_proxy 192.168.2.106:8080
              '';
            "recepten.apps.powerlan.empire".extraConfig =
              acmeTls
              + ''
                reverse_proxy 192.168.2.106:8080
              '';
            "home.powerlan.empire".extraConfig =
              acmeTls
              + ''
                handle_path /icons/* {
                  root * ${../../../features/homepage/icons}
                  file_server
                }
                handle {
                  reverse_proxy 192.168.2.103:3000
                }
              '';
            "proxmox.powerlan.empire" = {
              # Console URLs contain short-lived authentication tickets.
              logFormat = lib.mkForce null;
              extraConfig = ''
                ${acmeTls}
                reverse_proxy https://192.168.2.100:8006 {
                  header_up Host {host}
                  flush_interval -1
                  stream_close_delay 5m
                  transport http {
                    tls_server_name 192.168.2.100
                    tls_trust_pool file ${./proxmox-ca.crt}
                  }
                }
              '';
            };
            "homeassistant.powerlan.empire" = {
              logFormat = lib.mkForce null;
              extraConfig = ''
                ${acmeTls}
                reverse_proxy 192.168.2.109:8123
              '';
            };
            "forgejo.powerlan.empire".extraConfig = ''
              ${acmeTls}
              reverse_proxy https://192.168.2.110:8443 {
                header_up Host forgejo-backend.powerlan.empire
                transport http {
                  tls_server_name forgejo-backend.powerlan.empire
                  tls_trust_pool file ${backendCaCert}
                }
              }
            '';
            "forgejo.home.arpa".extraConfig = ''
              ${acmeTls}
              redir https://forgejo.powerlan.empire{uri} permanent
            '';
          };
        };
      };

      systemd.services = {
        proxy-data-init = {
          description = "Initialize only the designated, zero-filled proxy data disk";
          requiredBy = [
            "srv-proxy.mount"
          ];
          before = [
            "srv-proxy.mount"
          ];
          after = [
            "systemd-udev-trigger.service"
          ];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "10min";
          };
          path = [
            pkgs.coreutils
          ];
          script = ''
            for attempt in $(seq 1 15); do
              if [ -b /dev/disk/by-id/virtio-proxy-state ]; then
                exec ${initializeDisk}/bin/proxy-initialize-disk /dev/disk/by-id/virtio-proxy-state proxy-state
              fi
              sleep 1
            done
            echo 'Missing proxy data disk: /dev/disk/by-id/virtio-proxy-state' >&2
            exit 1
          '';
        };
        proxy-data-directories = {
          description = "Create Caddy directory only on the mounted proxy data disk";
          requiredBy = [
            "caddy.service"
          ];
          before = [
            "caddy.service"
          ];
          requires = [
            "srv-proxy.mount"
          ];
          after = [
            "srv-proxy.mount"
          ];
          unitConfig.AssertPathIsMountPoint = "/srv/proxy";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            pkgs.coreutils
          ];
          script = ''
            install -d -m 0700 -o caddy -g caddy /srv/proxy/caddy-acme
          '';
        };
        caddy = {
          requires = [
            "proxy-data-directories.service"
            "srv-proxy.mount"
          ];
          after = [
            "proxy-data-directories.service"
            "srv-proxy.mount"
          ];
          unitConfig.AssertPathIsMountPoint = "/srv/proxy";
        };
        forgejo-ssh = {
          description = "Forward Forgejo SSH to VM 110";
          serviceConfig = {
            ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 192.168.2.110:2222";
            DynamicUser = true;
          };
        };
      };
      systemd.sockets.forgejo-ssh = {
        description = "Forgejo SSH entry point";
        wantedBy = [
          "sockets.target"
        ];
        listenStreams = [
          "2222"
        ];
      };

      users.users.${main-user} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpqILWYPLnnke+4O3dAj61p8p+RghxZhTuP32TP6l07 david@nixos"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaTWrJGOvCf4dpAechU1ak3L+cylIrQtnjZsyMk/nSk david@nixos"
        ];
      };
      security.sudo.wheelNeedsPassword = false;
      system.stateVersion = "26.05";
    };
  };
}
