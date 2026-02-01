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
      efiInstallAsRemovable = true;
      useOSProber = true;
    };
    loader.timeout = 3;
    loader.efi.canTouchEfiVariables = false;

    # Enable USB automounting for external drives.
    supportedFilesystems = ["exfat" "ntfs"];

    kernel = {
      sysctl = {
        # for project ctb; Traefik needs to bind to low ports
        "net.ipv4.ip_unprivileged_port_start" = 80;

        # Increase hung task timeout for better handling of NVMe drives going to sleep
        "kernel.hung_task_timeout_secs" = 60;
      };
    };

    kernelParams = [
      # This is to fix the sleep breaking KDE Plasma issue
      "mem_sleep_default=s2idle"
      "nvme_core.default_ps_max_latency_us=0"
    ];
  };
}
