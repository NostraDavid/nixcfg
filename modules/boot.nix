{...}: {
  # Bootloader.
  boot = {
    # Temporarily using GRUB due to systemd 257 EFI variables bug
    # See: https://github.com/systemd/systemd/issues/35858
    loader.systemd-boot.enable = false;
    loader.grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
    };
    loader.efi.canTouchEfiVariables = true;

    # Enable USB automounting for external drives.
    supportedFilesystems = ["exfat" "ntfs"];

    kernel = {
      sysctl = {
        # for project ctb; Traefik needs to bind to low ports
        "net.ipv4.ip_unprivileged_port_start" = 80;
      };
    };
  };
}
