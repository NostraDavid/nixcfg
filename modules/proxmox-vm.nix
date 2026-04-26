{
  config,
  lib,
  pkgs,
  ...
}: {
  boot = {
    initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];
    kernelModules = ["kvm-intel" "kvm-amd"];
    loader.grub = {
      enable = true;
      device = "/dev/vda";
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
    firewall.enable = true;
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
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
