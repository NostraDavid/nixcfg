{mkHost, ...}: let
  settings = import ../../infra/proxmox-lab/settings.nix;
in {
  flake.nixosConfigurations.forgejo-lab = mkHost {
    hostname = settings.forgejo.hostname;
    module = {
      modulesPath,
      pkgs,
      ...
    }: {
      imports = [
        "${modulesPath}/profiles/qemu-guest.nix"
        ../server-locale.nix
        ../server-nix.nix
        ../forgejo.nix
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
        nameservers = [settings.gateway];
      };
      lab.forgejo = {
        enable = true;
        address = settings.forgejo.address;
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
        kernelParams = ["console=ttyS0"];
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
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = [settings.sshPublicKey];
      };
      security.sudo.wheelNeedsPassword = false;
      environment.systemPackages = [pkgs.git pkgs.curl];
      time.timeZone = "Europe/Amsterdam";
      system.stateVersion = "26.05";
    };
  };
}
