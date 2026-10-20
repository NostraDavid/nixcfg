{
  den,
  constructors,
  ...
}: {
  den.hosts.x86_64-linux.apps = {
    aspect = den.aspects.host-apps;
    instantiate = constructors.nixos {
      hostname = "apps";
    };
  };

  den.aspects.host-apps = {
    includes = with den.aspects; [
      proxmox-guest
      selfhosted-apps
    ];
    nixos = {main-user, ...}: {
      imports = [
        ./hardware-configuration.nix
      ];

      networking.hostName = "apps";
      users.users.${main-user} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpqILWYPLnnke+4O3dAj61p8p+RghxZhTuP32TP6l07 david@nixos"
        ];
      };
      fileSystems = {
        "/var/lib/postgresql" = {
          device = "/dev/disk/by-label/apps-postgres";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.device-timeout=10s"
          ];
        };
        "/srv/apps" = {
          device = "/dev/disk/by-label/apps-data";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.device-timeout=10s"
          ];
        };
      };
      system.stateVersion = "25.11";
    };
  };
}
