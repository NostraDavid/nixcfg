{
  flake.modules.nixos.nvidia-workstation = {
    config,
    pkgs,
    ...
  }: {
    boot = {
      kernelPackages = pkgs.linuxPackages_6_12;
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
      nix-ld.libraries = with pkgs; [
        libGL
        libglvnd
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
      systemPackages = with pkgs; [
        android-tools
        espeak-ng
        flite
        libva-utils
        cudaPackages.cudatoolkit
        cudaPackages.cudnn
        cudaPackages.nccl
        nvtopPackages.full
      ];
      # Keep Wayland sessions hidden so SDDM only offers X11.
      etc."xdg/wayland-sessions".source = pkgs.emptyDirectory;
    };

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      gsp.enable = false;
      open = false;
      nvidiaSettings = true;
      nvidiaPersistenced = true;
      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "570.195.03";
        sha256_64bit = "sha256-1H3oHZpRNJamCtyc+nL+nhYsZfJyL7lgxPUxvXrF3B4=";
        settingsSha256 = "sha256-mjKkMEPV6W69PO8jKAKxAS861B82CtCpwVTeNr5CqUY=";
        persistencedSha256 = "sha256-BMpo2PIabhHjZQqUQi/W5DYhgAPmfCdFvXdN6ND2Bfs=";
      };
    };
  };
}
