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
      stable,
      ...
    }: {
      imports = with flakeConfig.flake.modules.nixos; [
        ../../hosts/donar/hardware-configuration.nix
        full-workstation
        laptop
      ];

      system.stateVersion = "26.05";

      boot = {
        kernelPackages = stable.linuxPackages_latest;

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

      # Bluetooth headset profiles combine playback and microphone audio in a
      # single mono channel. Keep headphones on A2DP stereo when an application
      # (such as a game with voice chat) opens a microphone; use Donar's built-in
      # microphone separately when voice input is needed.
      services.pipewire.wireplumber.extraConfig."51-bluetooth-stereo" = {
        "wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };

      environment.systemPackages = [
        stable.libva-utils
        stable.nvtopPackages.full
      ];
    };
  };
}
