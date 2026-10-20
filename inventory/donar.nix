{
  den,
  constructors,
  inputs,
  ...
}: {
  den.hosts.x86_64-linux.donar = {
    aspect = den.aspects.host-donar;
    instantiate = constructors.nixos {
      hostname = "donar";
      homeManager = true;
    };
    users.david = {
      classes = [
        "homeManager"
      ];
      aspect.includes = [
        den.batteries.host-aspects
      ];
    };
  };

  den.aspects.host-donar = {
    includes = with den.aspects; [
      full-workstation
      laptop
    ];
    nixos = {
      config,
      lib,
      stable,
      ...
    }: {
      imports = [
        ../hosts/donar/hardware-configuration.nix
      ];

      networking.hostName = "donar";

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
      services.xserver.videoDrivers = lib.mkForce [
        "nvidia"
      ];
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
      fileSystems."/media/usb" = {
        device = "/dev/disk/by-uuid/a0ff5645-3695-4a32-9917-51d98d453d21";
        fsType = "vfat";
        options = [
          "nofail"
          "x-systemd.automount"
        ];
      };
    };
    homeManager = {
      imports = [
        # These integrations declare options; host features select their settings.
        inputs.plasma-manager.homeModules.plasma-manager
        inputs.codex-desktop-linux.homeManagerModules.default
      ];
      programs.home-manager.enable = true;
      home = {
        username = "david";
        homeDirectory = "/home/david";
        stateVersion = "25.05";
      };
    };
  };
}
