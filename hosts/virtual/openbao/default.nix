{
  den,
  constructors,
  ...
}: {
  den.hosts.x86_64-linux.openbao = {
    aspect = den.aspects.host-openbao;
    instantiate = constructors.nixos {hostname = "openbao";};
  };

  den.aspects.host-openbao = {
    includes = with den.aspects; [openbao proxmox-guest];
    nixos = {
      lib,
      main-user,
      ...
    }: {
      networking = {
        hostName = "openbao";
        useDHCP = false;
        interfaces.ens18.ipv4.addresses = [
          {
            address = "192.168.2.112";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.2.1";
        nameservers = ["192.168.2.102"];
        firewall.allowedTCPPorts = lib.mkForce [];
        firewall.extraCommands = lib.mkForce ''
          iptables -w -A nixos-fw -s 192.168.2.0/24 -p tcp -m multiport --dports 22,443 -j nixos-fw-accept
        '';
      };
      fileSystems = {
        "/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        "/srv/openbao" = {
          device = "/dev/disk/by-label/openbao-state";
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
