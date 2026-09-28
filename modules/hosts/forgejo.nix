{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.forgejo = mkHost {
    hostname = "forgejo";
    module = {
      lib,
      main-user,
      ...
    }: {
      imports = [
        config.flake.modules.nixos.proxmox-guest
        ../forgejo.nix
      ];

      networking = {
        hostName = "forgejo";
        useDHCP = false;
        interfaces.ens18.ipv4.addresses = [
          {
            address = "192.168.2.110";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.2.1";
        nameservers = ["192.168.2.102"];
        firewall.allowedTCPPorts = lib.mkForce [2222];
        firewall.extraCommands = lib.mkForce ''
          iptables -w -A nixos-fw -s 192.168.2.0/24 -p tcp --dport 22 -j nixos-fw-accept
          iptables -w -A nixos-fw -s 192.168.2.111/32 -p tcp --dport 8443 -j nixos-fw-accept
        '';
      };
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
      boot = {
        loader.grub.device = lib.mkForce "/dev/vda";
        initrd.availableKernelModules = ["virtio_blk"];
        kernelParams = ["console=ttyS0"];
      };
      services = {
        qemuGuest.enable = true;
        forgejo.settings.server.HTTP_ADDR = lib.mkForce "127.0.0.1";
        forgejo.settings."cron.sync_external_users" = {
          ENABLED = true;
          RUN_AT_START = true;
          SCHEDULE = "@every 1h";
        };
        caddy = {
          enable = true;
          dataDir = "/srv/forgejo/caddy";
          globalConfig = ''
            skip_install_trust
            servers {
              trusted_proxies static 192.168.2.111/32
              trusted_proxies_strict
            }
            pki {
              ca backend {
                name "Forgejo Backend CA"
              }
            }
          '';
          virtualHosts."forgejo-backend.powerlan.empire:8443".extraConfig = ''
            tls {
              issuer internal {
                ca backend
              }
            }
            reverse_proxy 127.0.0.1:3000
          '';
        };
      };
      security.pki.certificateFiles = [../../hosts/wodan/certs/freeipa.crt];

      nixcfg.forgejo = {
        enable = true;
        domain = "forgejo.powerlan.empire";
        rootUrl = "https://forgejo.powerlan.empire/";
        adminEmail = "david@forgejo.home.arpa";
      };

      systemd.tmpfiles.rules = [
        "d /srv/forgejo/caddy 0700 caddy caddy -"
      ];
      systemd.services.caddy = {
        requires = ["srv-forgejo.mount" "forgejo-data-directories.service"];
        after = ["srv-forgejo.mount" "forgejo-data-directories.service"];
        unitConfig.AssertPathIsMountPoint = "/srv/forgejo";
      };

      users.users.${main-user} = {
        isNormalUser = true;
        extraGroups = ["wheel"];
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
