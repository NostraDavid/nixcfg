{
  config,
  mkHost,
  ...
}: let
  flakeConfig = config;
in {
  flake.nixosConfigurations.donar = mkHost {
    hostname = "donar";
    module = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = with flakeConfig.flake.modules.nixos; [
        ../../hosts/donar/hardware-configuration.nix
        kde-workstation
        laptop
        browsers-extra
        communication-extra
        desktop-apps-extra
        development-extra
        gaming
        media-extra
        whatpulse
      ];

      system.stateVersion = "26.05";

      boot = {
        kernelPackages = pkgs.linuxPackages_latest;

        # Donar was installed with systemd-boot. Keep using its existing EFI
        # entry instead of inheriting Wodan's removable GRUB setup.
        loader = {
          systemd-boot.enable = lib.mkForce true;
          grub.enable = lib.mkForce false;
          efi.canTouchEfiVariables = lib.mkForce true;
        };
      };

      # The Legion 5 Pro has an AMD iGPU and an NVIDIA dGPU. Keep the dGPU
      # available for demanding applications without powering it continuously.
      services.xserver.videoDrivers = lib.mkForce ["nvidia"];
      nixpkgs.config.nvidia.acceptLicense = true;
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        powerManagement.finegrained = true;
        open = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.production;
        prime = {
          offload = {
            enable = true;
            enableOffloadCmd = true;
          };
          amdgpuBusId = "PCI:5:0:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };

      environment.systemPackages = with pkgs; [
        libva-utils
        nvtopPackages.full
      ];
    };
  };
}
