{
  lib,
  main-user,
  stable,
  ...
}: {
  boot = {
    initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];
    kernelModules = ["kvm-intel" "kvm-amd"];
    loader.grub = {
      enable = true;
      device = "/dev/sda";
    };
    loader.timeout = 1;
  };

  environment.systemPackages = [
    stable.curl
    stable.git
    stable.btop
    stable.vim
    stable.neovim
  ];

  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager.enable = false;
    firewall = {
      enable = true;
      extraCommands = ''
        iptables -w -A nixos-fw -s 192.168.2.0/24 -p tcp -m multiport --dports 22,80,443 -j nixos-fw-accept
      '';
    };
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      AllowUsers = [main-user];
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  time.timeZone = "Europe/Amsterdam";

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 1024;
      cores = 1;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
