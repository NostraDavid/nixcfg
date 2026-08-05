{
  flake.modules.nixos.nvidia-workstation = {
    config,
    stable,
    ...
  }: {
    boot = {
      kernelPackages = stable.linuxPackages_latest;
      extraModprobeConfig = ''
        options nvidia NVreg_PreserveVideoMemoryAllocations=1
      '';
    };

    services = {
      xserver.videoDrivers = ["nvidia"];
      udev.extraRules = ''
        # Nvidia GPU power management - keep GPU powered on when in use
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="on"

        # NVMe SSD power management - set to mq-deadline scheduler
        ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="mq-deadline"
      '';
    };

    programs = {
      nix-ld.libraries = [
        stable.libGL
        stable.libglvnd
      ];
      firefox.preferences = {
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
      };
    };

    nixpkgs.config.nvidia.acceptLicense = true;

    environment = {
      sessionVariables = {
        LIBVA_DRIVER_NAME = "radeonsi";
        MOZ_DRM_DEVICE = "/dev/dri/by-path/pci-0000:79:00.0-render";
      };
      systemPackages = [
        stable.android-tools
        stable.espeak-ng
        stable.flite
        stable.libva-utils
        stable.cudaPackages.cudatoolkit
        stable.cudaPackages.cudnn
        stable.cudaPackages.nccl
        stable.nvtopPackages.full
      ];
      # Keep Wayland sessions hidden so SDDM only offers X11.
      etc."xdg/wayland-sessions".source = stable.emptyDirectory;
    };

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      gsp.enable = false;
      open = false;
      nvidiaSettings = true;
      nvidiaPersistenced = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };
  };
}
