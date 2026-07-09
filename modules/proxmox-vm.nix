{
  lib,
  main-user,
  pkgs,
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

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    vim
  ];

  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager.enable = false;
    firewall = {
      enable = true;
      extraInputRules = ''
        ip saddr 192.168.2.0/24 tcp dport { 22, 80, 443 } accept
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
