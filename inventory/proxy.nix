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
        text = builtins.readFile ../scripts/lab-initialize-disk.sh;
      };
      backendCaCert = "/srv/proxy/backend-root.crt";
      certificateFiles = [
        "fingerprints.txt"
        "forgejo-ca.crt"
        "freeipa.crt"
        "SHA256SUMS"
      ];
      bundleVersion = let
        version = lib.removeSuffix "\n" (builtins.readFile ../certs/VERSION);
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
          cp ${../certs/freeipa.crt} freeipa.crt
          cp ${../certs/forgejo-ca.crt} forgejo-ca.crt
          cp ${../certs/fingerprints.txt} fingerprints.txt
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
                (builtins.readFile ../certs/fingerprints.txt)
                bundleVersion
              ]
              (builtins.readFile ../certs/index.html));
          }
        ]
        ++ map (name: {
          inherit name;
          path = ../certs + "/${name}";
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
          root * /srv/proxy/certificates
          file_server browse
        }
        handle {
          root * ${certificateSite}
          file_server
        }
      '';
    in {
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
          dataDir = "/srv/proxy/caddy";
          globalConfig = "skip_install_trust";
          virtualHosts = {
            "http://192.168.2.111".extraConfig = certificateSiteConfig;
            "https://192.168.2.111".extraConfig = "tls internal\n" + certificateSiteConfig;
            "forgejo.powerlan.empire".extraConfig = ''
              tls internal
              reverse_proxy https://192.168.2.110:8443 {
                header_up Host forgejo-backend.powerlan.empire
                transport http {
                  tls_server_name forgejo-backend.powerlan.empire
                  tls_trust_pool file ${backendCaCert}
                }
              }
            '';
            "forgejo.home.arpa".extraConfig = ''
              tls internal
              redir https://forgejo.powerlan.empire{uri} permanent
            '';
          };
        };
      };

      systemd.services = {
        certificate-releases = {
          description = "Preserve immutable public CA bundles on the proxy state disk";
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
            "srv-proxy.mount"
          ];
          after = [
            "srv-proxy.mount"
          ];
          unitConfig.AssertPathIsMountPoint = "/srv/proxy";
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
            install -d -m 0755 /srv/proxy/certificates/releases
            destination=/srv/proxy/certificates/releases/${bundleVersion}
            if [ -d "$destination" ]; then
              if ! ${pkgs.diffutils}/bin/cmp -s ${certificateRelease}/powerlan-ca.zip.sha256 "$destination/powerlan-ca.zip.sha256"; then
                echo 'Bundle contents changed: bump certs/VERSION before publishing.' >&2
                exit 1
              fi
            else
              staging=$(mktemp -d /srv/proxy/certificates/.release.XXXXXXXX)
              trap 'rm -rf "$staging"' EXIT
              install -m 0644 ${certificateRelease}/* "$staging/"
              chmod 0755 "$staging"
              mv -T "$staging" "$destination"
              trap - EXIT
            fi
          '';
        };
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
            install -d -m 0700 -o caddy -g caddy /srv/proxy/caddy
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
