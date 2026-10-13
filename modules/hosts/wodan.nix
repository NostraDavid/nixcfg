{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.wodan = mkHost {
    hostname = "wodan";
    module = {
      inputs,
      lib,
      stable,
      ...
    }: {
      imports = with config.flake.modules.nixos; [
        ../../hosts/wodan/hardware-configuration.nix
        full-workstation
        nvidia-workstation
        wodan-home
        proxmox-lab-host
        (inputs.nixos-vex + "/modules")
      ];

      nixosVex.strict = false;

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
        kernel.sysctl."fs.inotify.max_user_watches" = 4194304;
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
        podman = {
          enable = true;
          wantedBy = ["default.target"];
        };
        legcord = {
          enable = true;
          after = ["network.target"];
          description = "Legcord Discord Client";
          serviceConfig = {
            Type = "simple";
            ExecStart = "${stable.legcord}/bin/legcord";
          };
        };
      };

      security.pki.certificateFiles = [
        ../../hosts/wodan/certs/pihole.crt
        ../../hosts/wodan/certs/proxmox.crt
      ];
    };
  };
}
