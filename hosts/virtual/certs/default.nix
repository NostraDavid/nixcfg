{
  den,
  constructors,
  ...
}: {
  den.hosts.x86_64-linux.certs = {
    aspect = den.aspects.host-certs;
    instantiate = constructors.nixos {hostname = "certs";};
  };
  den.aspects.host-certs = {
    includes = with den.aspects; [pihole-tls-server proxmox-guest];
    nixos = {
      config,
      lib,
      main-user,
      pkgs,
      ...
    }: let
      initializeDisk = pkgs.writeShellApplication {
        name = "certs-initialize-disk";
        runtimeInputs = [
          pkgs.util-linux
          pkgs.e2fsprogs
          pkgs.diffutils
          pkgs.coreutils
        ];
        text = builtins.readFile ../../../scripts/lab-initialize-disk.sh;
      };
      certificateFiles = [
        "fingerprints.txt"
        "forgejo-ca.crt"
        "freeipa.crt"
        "SHA256SUMS"
      ];
      bundleVersion = let
        version = lib.removeSuffix "\n" (builtins.readFile ../../../certs/VERSION);
      in
        assert lib.assertMsg
        (builtins.match "(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)" version != null)
        "certs/VERSION must contain stable SemVer: MAJOR.MINOR.PATCH."; version;
      certificateRelease =
        pkgs.runCommand "powerlan-ca-release" {
          nativeBuildInputs = [
            pkgs.zip
          ];
        } ''
          mkdir -p "$out"
          cd "$out"
          cp ${../../../certs/freeipa.crt} freeipa.crt
          cp ${../../../certs/forgejo-ca.crt} forgejo-ca.crt
          cp ${../../../certs/fingerprints.txt} fingerprints.txt
          cat freeipa.crt forgejo-ca.crt > powerlan-ca.pem
          printf '%s\n' '${bundleVersion}' > version.txt
          sha256sum freeipa.crt forgejo-ca.crt powerlan-ca.pem fingerprints.txt version.txt > SHA256SUMS
          touch -t 198001010000 ./*
          zip -X -0 powerlan-ca.zip freeipa.crt forgejo-ca.crt powerlan-ca.pem fingerprints.txt version.txt SHA256SUMS
          sha256sum powerlan-ca.zip > powerlan-ca.zip.sha256
        '';
      certificateSite = pkgs.linkFarm "internal-ca-site" (
        [
          {
            name = "index.html";
            path = pkgs.writeText "internal-ca-index.html" (builtins.replaceStrings
              [
                "@FINGERPRINTS@"
                "@BUNDLE_VERSION@"
              ]
              [
                (builtins.readFile ../../../certs/fingerprints.txt)
                bundleVersion
              ]
              (builtins.readFile ../../../certs/index.html));
          }
        ]
        ++ map (name: {
          inherit name;
          path = ../../../certs + "/${name}";
        })
        certificateFiles
      );
      certificateSiteConfig = ''
        @latest path /powerlan-ca-latest.zip /powerlan-ca-latest.pem
        header @latest Cache-Control no-store
        redir /powerlan-ca-latest.zip /releases/${bundleVersion}/powerlan-ca.zip 302
        redir /powerlan-ca-latest.pem /releases/${bundleVersion}/powerlan-ca.pem 302
        @certificates path /freeipa.crt /forgejo-ca.crt
        header @certificates {
          Content-Type application/x-x509-ca-cert
          Content-Disposition attachment
        }
        handle /releases/* {
          @versioned not path /releases/
          header @versioned Cache-Control "public, max-age=31536000, immutable"
          header /releases/ Cache-Control no-store
          root * /srv/certs/certificates
          file_server browse
        }
        handle {
          root * ${certificateSite}
          file_server
        }
      '';
      serverTls = ''
        tls {
          issuer internal {
            lifetime 8760h
          }
        }
      '';
    in {
      environment.systemPackages = [pkgs.openssl pkgs.age];
      networking = {
        hostName = "certs";
        useDHCP = false;
        interfaces.ens18.ipv4.addresses = [
          {
            address = "192.168.2.113";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.2.1";
        nameservers = ["192.168.2.102"];
        firewall.extraCommands = ''
          iptables -w -A nixos-fw -s 192.168.2.111 -p tcp --dport 8443 -j nixos-fw-accept
          iptables -w -A nixos-fw -s 10.0.1.0/24 -p tcp --dport 22 -j nixos-fw-accept
        '';
      };
      fileSystems = {
        "/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        "/srv/certs" = {
          device = "/dev/disk/by-label/certs-state";
          fsType = "ext4";
          options = ["nofail" "x-systemd.device-timeout=11min"];
        };
      };
      boot = {
        loader.grub.device = lib.mkForce "/dev/vda";
        initrd.availableKernelModules = ["virtio_blk"];
        kernelParams = ["console=ttyS0"];
      };
      services.qemuGuest.enable = true;
      services.caddy = {
        enable = true;
        dataDir = "/srv/certs/caddy";
        globalConfig = ''
          skip_install_trust
          pki {
            ca local {
              intermediate_lifetime 43800h
            }
          }
        '';
        virtualHosts = {
          "http://192.168.2.113".extraConfig = certificateSiteConfig;
          "https://192.168.2.113".extraConfig = serverTls + certificateSiteConfig;
          "certs.powerlan.empire".extraConfig = config.services.caddy.virtualHosts."https://192.168.2.113".extraConfig;
          "https://192.168.2.113:8443" = {
            logFormat = lib.mkForce null;
            extraConfig =
              serverTls
              + ''
                acme_server {
                  lifetime 8760h
                  resolvers 192.168.2.102
                  allow {
                    domains k3s.powerlan.empire forgejo.powerlan.empire forgejo.home.arpa proxmox.powerlan.empire home.powerlan.empire homeassistant.powerlan.empire poc.apps.powerlan.empire ctb.apps.powerlan.empire huishoudboekje.apps.powerlan.empire recepten.apps.powerlan.empire
                    ip_ranges 192.168.2.111/32
                  }
                }
              '';
          };
        };
      };
      systemd.services = {
        certificate-releases = {
          description = "Preserve immutable public CA bundles on the certificate state disk";
          wantedBy = [
            "multi-user.target"
          ];
          requiredBy = [
            "caddy.service"
          ];
          before = [
            "caddy.service"
          ];
          requires = [
            "srv-certs.mount"
          ];
          after = [
            "srv-certs.mount"
          ];
          unitConfig.AssertPathIsMountPoint = "/srv/certs";
          restartTriggers = [
            certificateRelease
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            pkgs.coreutils
          ];
          script = ''
            install -d -m 0755 /srv/certs/certificates/releases
            destination=/srv/certs/certificates/releases/${bundleVersion}
            if [ -d "$destination" ]; then
              if ! ${pkgs.diffutils}/bin/cmp -s ${certificateRelease}/powerlan-ca.zip.sha256 "$destination/powerlan-ca.zip.sha256"; then
                echo 'Bundle contents changed: bump certs/VERSION before publishing.' >&2
                exit 1
              fi
            else
              staging=$(mktemp -d /srv/certs/certificates/.release.XXXXXXXX)
              trap 'rm -rf "$staging"' EXIT
              install -m 0644 ${certificateRelease}/* "$staging/"
              chmod 0755 "$staging"
              mv -T "$staging" "$destination"
              trap - EXIT
            fi
          '';
        };
        certs-data-init = {
          description = "Initialize only the designated, zero-filled certificate data disk";
          requiredBy = [
            "srv-certs.mount"
          ];
          before = [
            "srv-certs.mount"
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
              if [ -b /dev/disk/by-id/virtio-certs-state ]; then
                exec ${initializeDisk}/bin/certs-initialize-disk /dev/disk/by-id/virtio-certs-state certs-state
              fi
              sleep 1
            done
            echo 'Missing certificate data disk: /dev/disk/by-id/virtio-certs-state' >&2
            exit 1
          '';
        };
        certs-data-directories = {
          description = "Create Caddy directory only on the mounted certificate data disk";
          requiredBy = [
            "caddy.service"
          ];
          before = [
            "caddy.service"
          ];
          requires = [
            "srv-certs.mount"
          ];
          after = [
            "srv-certs.mount"
          ];
          unitConfig.AssertPathIsMountPoint = "/srv/certs";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            pkgs.coreutils
          ];
          script = ''
            install -d -m 0700 -o caddy -g caddy /srv/certs/caddy
          '';
        };
        caddy = {
          requires = [
            "certs-data-directories.service"
            "srv-certs.mount"
          ];
          after = [
            "certs-data-directories.service"
            "srv-certs.mount"
          ];
          unitConfig.AssertPathIsMountPoint = "/srv/certs";
        };
      };
      # Import the existing trusted root before the first Caddy start.
      systemd.services.caddy.unitConfig.ConditionPathExists = "/srv/certs/caddy/.local/share/caddy/pki/authorities/local/root.key";
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
