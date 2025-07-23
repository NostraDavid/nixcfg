{...}: {
  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # Enable USB automounting for external drives.
    supportedFilesystems = ["exfat" "ntfs"];
  };
}
