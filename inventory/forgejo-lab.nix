{
  den,
  constructors,
  ...
}: let
  settings = import ../infra/proxmox-lab/settings.nix;
in {
  den.hosts.x86_64-linux.forgejo-lab = {
    aspect = den.aspects.host-forgejo-lab;
    instantiate = constructors.nixos {
      hostname = settings.forgejo.hostname;
    };
  };

  den.aspects.host-forgejo-lab = {
    includes = with den.aspects; [
      forgejo
      server-locale
      server-nix
    ];
    nixos = {
      modulesPath,
      pkgs,
      ...
    }: {
      imports = [
        "${modulesPath}/profiles/qemu-guest.nix"
      ];

      networking = {
        hostName = settings.forgejo.hostname;
        useDHCP = false;
        usePredictableInterfaceNames = false;
        interfaces.eth0.ipv4.addresses = [
          {
            address = settings.forgejo.address;
            prefixLength = settings.prefix;
          }
        ];
        defaultGateway = settings.gateway;
        nameservers = [
          settings.gateway
        ];
      };
      nixcfg.forgejo = {
        enable = true;
        domain = settings.forgejo.address;
        appName = "Forgejo lab";
        adminEmail = "david@forgejo-lab.home.arpa";
      };
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
        autoResize = true;
      };
      boot = {
        growPartition = true;
        loader.grub = {
          enable = true;
          device = "/dev/vda";
        };
        kernelParams = [
          "console=ttyS0"
        ];
        loader.timeout = 1;
      };
      services.qemuGuest.enable = true;
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
      };
      users.users.david = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
        ];
        openssh.authorizedKeys.keys = [
          settings.sshPublicKey
        ];
      };
      security.sudo.wheelNeedsPassword = false;
      environment.systemPackages = [
        pkgs.curl
        pkgs.git
      ];
      time.timeZone = "Europe/Amsterdam";
      fileSystems."/srv/forgejo" = {
        device = "/dev/disk/by-label/forgejo-state";
        fsType = "ext4";
        options = [
          "nofail"
          "x-systemd.device-timeout=11min"
        ];
      };
      system.stateVersion = "26.05";
    };
  };
}
