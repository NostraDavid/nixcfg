{...}: {
  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
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
