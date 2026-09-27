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

      networking.hostName = "forgejo";
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
        caddy = {
          enable = true;
          dataDir = "/srv/forgejo/caddy";
          globalConfig = "skip_install_trust";
          virtualHosts."forgejo.home.arpa".extraConfig = ''
            tls internal
            reverse_proxy 127.0.0.1:3000
          '';
        };
      };

      nixcfg.forgejo = {
        enable = true;
        domain = "forgejo.home.arpa";
        rootUrl = "https://forgejo.home.arpa/";
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

      networking.firewall.allowedTCPPorts = lib.mkForce [2222];

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
