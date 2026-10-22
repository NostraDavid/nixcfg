{
  den,
  constructors,
  inputs,
  self,
  ...
}: {
  den = {
    hosts.x86_64-linux.wodan = {
      aspect = den.aspects.host-wodan;
      instantiate = constructors.nixos {
        hostname = "wodan";
        homeManager = true;
      };
      users.david = {
        classes = [
          "homeManager"
        ];
        aspect.includes = [
          den.batteries.host-aspects
        ];
      };
    };

    aspects = {
      host-wodan = {
        includes = with den.aspects; [
          full-workstation
          nvidia-workstation
          proxmox-lab-host
          wodan
        ];
        nixos = {
          inputs,
          lib,
          stable,
          ...
        }: {
          imports = [
            ./hardware-configuration.nix
            (inputs.nixos-vex + "/modules")
          ];

          nixosVex.strict = false;

          networking.hostName = "wodan";

          system.stateVersion = "25.05";

          boot = {
            blacklistedKernelModules = [
              "ahci"
              "ath12k"
              "battery"
              "btusb"
              "jfs"
              "mac_hid"
              "thunderbolt"
            ];
            # JFS is unused; block explicit loads as well as filesystem autoloading.
            extraModprobeConfig = ''
              install jfs ${stable.coreutils}/bin/false
            '';
            kernel.sysctl."fs.inotify.max_user_watches" = 33554432;
          };

          services = {
            openssh.enable = lib.mkForce false;
            xserver.xkb.options = "caps:escape_shifted_compose,lv3:ralt_switch_multikey,compose:ralt,compose:rctrl,mod_led:compose,grp:win_space_toggle";
            xrdp = {
              enable = true;
              defaultWindowManager = "startplasma-x11";
              openFirewall = true;
            };
          };

          systemd.user.services = {
            # dbus-broker v37 can disable SIGHUP reloads after inotify exhaustion.
            dbus-broker.serviceConfig = {
              Type = "notify";
              ExecReload = "${stable.systemd}/bin/busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig";
            };
            podman = {
              enable = true;
              wantedBy = [
                "default.target"
              ];
            };
            legcord = {
              enable = true;
              after = [
                "network.target"
              ];
              description = "Legcord Discord Client";
              serviceConfig = {
                Type = "simple";
                ExecStart = "${stable.legcord}/bin/legcord";
              };
            };
          };

          security.pki.certificateFiles = [
            ./certs/pihole.crt
            ./certs/proxmox.crt
          ];
          fileSystems."/media/usb" = {
            device = "/dev/disk/by-uuid/a0ff5645-3695-4a32-9917-51d98d453d21";
            fsType = "vfat";
            options = [
              "nofail"
              "x-systemd.automount"
            ];
          };
        };
        homeManager = {
          imports = [
            # These integrations declare options; host features select their settings.
            inputs.plasma-manager.homeModules.plasma-manager
            inputs.codex-desktop-linux.homeManagerModules.default
          ];
          programs.home-manager.enable = true;
          home = {
            username = "david";
            homeDirectory = "/home/david";
            stateVersion = "25.05";
          };
        };
      };
      wodan = {
        includes = [
          den.aspects.codex-browser
        ];
        homeManager = import ./_home.nix;
      };
      proxmox-lab-host.nixos = import ./_proxmox-lab-host.nix {inherit self;};
    };
  };
}
