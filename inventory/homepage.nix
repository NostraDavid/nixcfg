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
    nixos = {main-user, ...}: {
      imports = [
        ../servers/homepage/hardware-configuration.nix
      ];

      networking.hostName = "homepage";
      users.users.${main-user} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpqILWYPLnnke+4O3dAj61p8p+RghxZhTuP32TP6l07 david@nixos"
        ];
      };
      fileSystems."/var/lib/homepage" = {
        device = "/dev/disk/by-label/homepage-data";
        fsType = "ext4";
        options = [
          "nofail"
          "x-systemd.device-timeout=10s"
        ];
      };
      system.stateVersion = "25.11";
    };
  };
}
