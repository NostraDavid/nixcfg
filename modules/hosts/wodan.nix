{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.wodan = mkHost {
    hostname = "wodan";
    module = {pkgs, ...}: {
      imports = with config.flake.modules.nixos; [
        ../../hosts/wodan/hardware-configuration.nix
        workstation
        nvidia-workstation
        gaming
        whatpulse
      ];

      system.stateVersion = "25.05";

      services = {
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
            ExecStart = "${pkgs.legcord}/bin/legcord";
          };
        };
      };

      security.pki.certificateFiles = [
        ../../hosts/wodan/certs/freeipa.crt
        ../../hosts/wodan/certs/pihole.crt
        ../../hosts/wodan/certs/proxmox.crt
      ];
    };
  };
}
