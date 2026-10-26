{
  den,
  constructors,
  ...
}: {
  den.hosts.x86_64-linux.homepage = {
    aspect = den.aspects.host-homepage;
    instantiate = constructors.nixos {
      hostname = "homepage";
    };
  };

  den.aspects.host-homepage = {
    includes = with den.aspects; [
      homepage
      proxmox-guest
    ];
    nixos = {
      main-user,
      lib,
      ...
    }: {
      imports = [
        ./hardware-configuration.nix
      ];

      networking = {
        hostName = "homepage";
        useDHCP = lib.mkForce false;
        interfaces.ens18.ipv4.addresses = [
          {
            address = "192.168.2.103";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.2.1";
        nameservers = ["192.168.2.102"];
        firewall.extraCommands = ''
          iptables -w -A nixos-fw -s 192.168.2.111 -p tcp --dport 3000 -j nixos-fw-accept
          iptables -w -A nixos-fw -s 10.0.1.0/24 -p tcp --dport 22 -j nixos-fw-accept
        '';
      };
      services.qemuGuest.enable = true;
      security.sudo.wheelNeedsPassword = false;
      boot.kernelParams = ["console=ttyS0"];
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
      system.stateVersion = "25.11";
    };
  };
}
