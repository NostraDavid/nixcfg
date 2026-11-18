{
  den,
  constructors,
  ...
}: {
  den.hosts.x86_64-linux.nextcloud = {
    aspect = den.aspects.host-nextcloud;
    instantiate = constructors.nixos {hostname = "nextcloud";};
  };

  den.aspects.host-nextcloud = {
    includes = with den.aspects; [nextcloud proxmox-guest];
    nixos = {
      lib,
      main-user,
      ...
    }: let
      nextcloud = lib.importJSON ../../../infra/network/nextcloud.json;
    in {
      networking = {
        hostName = "nextcloud";
        useDHCP = false;
        interfaces.ens18.ipv4.addresses = [
          {
            inherit (nextcloud) address;
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.2.1";
        nameservers = ["192.168.2.102"];
        firewall.allowedTCPPorts = lib.mkForce [];
        firewall.extraCommands = lib.mkForce ''
          iptables -w -A nixos-fw -s 192.168.2.0/24 -p tcp --dport 22 -j nixos-fw-accept
          iptables -w -A nixos-fw -s 192.168.2.111/32 -p tcp --dport ${toString nextcloud.backendPort} -j nixos-fw-accept
        '';
      };
      fileSystems = {
        "/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        "/srv/nextcloud" = {
          device = "/dev/disk/by-label/nextcloud-state";
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
