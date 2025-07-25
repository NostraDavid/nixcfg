# wodan
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  hostname,
  main-user,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/boot.nix
    ../../modules/location.nix
    ../../modules/i18n.nix
    inputs.home-manager.nixosModules.home-manager
    (import ../../modules/home-manager.nix {inherit hostname main-user;})
  ];
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05";

  networking = {
    hostName = hostname;
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # proxy = {
    #   default = "http://user:password@proxy:port/";
    #   noProxy = "127.0.0.1,localhost,internal.domain";
    # };

    # Enable networking
    networkmanager.enable = true;

    # Open ports in the firewall.
    # firewall = {
    #   # Or disable the firewall altogether.
    #   enable = false;
    #   allowedTCPPorts = [ ... ];
    #   allowedUDPPorts = [ ... ];
    # };
  };

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services = {
    xserver = {
      enable = true;
      # Load nvidia driver for Xorg and Wayland
      videoDrivers = ["nvidia"];
      # Configure keymap in X11
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    # Enable automatic login for the user.
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = main-user;

    # Enable the KDE Plasma Desktop Environment.
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;

    # Enable CUPS to print documents.
    printing.enable = false;

    # NuPhy Air75HE, and Whatpulse support
    udev.extraRules = ''
      # Chromium Nuphy Air rules
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="hidraw", MODE="0660"

      # Whatpulse rules
      KERNEL=="event*", NAME="input/%k", MODE="640", GROUP="input"
    '';

    # Enable touchpad support (enabled default in most desktopManager).
    # xserver.libinput.enable = true;

    # Enable sound with pipewire.
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };

    # Enable the OpenSSH daemon.
    openssh.enable = true;

    udisks2.enable = true; # daemon that owns the mount
    gvfs.enable = true; # for GNOME, Thunar, etc.
    devmon.enable = true; # optional: instant automount helpers

    k3s = {
      enable = true;
      manifests.nginx.content = {
        apiVersion = "v1";
        kind = "Pod";
        metadata.name = "nginx";
        spec.containers = [
          {
            name = "nginx";
            image = "nginx:1.14.2";
            ports = [{containerPort = 80;}];
          }
        ];
      };
    };

    # https://github.com/ryan4yin/nix-config/blob/90f36202a916b3e6f893edf8a5a89862d83983bc/modules/nixos/base/monitoring.nix
    prometheus.exporters.node = {
      enable = false;
      listenAddress = "0.0.0.0";
      port = 9100;
      # There're already a lot of collectors enabled by default
      # https://github.com/prometheus/node_exporter?tab=readme-ov-file#enabled-by-default
      enabledCollectors = [
        "systemd"
        "logind"
      ];

      # use either enabledCollectors or disabledCollectors
      # disabledCollectors = [];
    };
  };

  # Enable sound with pipewire.
  security.rtkit.enable = true;

  users = {
    groups = {
      hidraw = {};
      input = {};
    };
    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.${main-user} = {
      # shell = pkgs.
      isNormalUser = true;
      description = "";
      # hidraw and input for Whatpulse and NuPhy Air75HE support (IIRC)
      extraGroups = ["networkmanager" "wheel" "hidraw" "input"];
      packages = with pkgs; [
        kdePackages.kate
      ];
    };
  };

  programs = {
    # enable appimage support, for Whatpulse and other AppImages
    appimage = {
      enable = true;
      binfmt = true;
    };
    # needed for Python packages that use C libraries
    nix-ld = {
      # https://wiki.nixos.org/wiki/Nix-ld
      enable = true;
      libraries = with pkgs; [
        freetype
      ];
    };
    firefox = {
      enable = true;
      # Add a simple Enterprise policy: trust whatever the OS trusts
      policies.Certificates.ImportEnterpriseRoots = true;
      languagePacks = [
        "en-US"
        "nl"
      ];
    };
    thunderbird.enable = true;
    starship.enable = false;
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # # Enable common container config files in /etc/containers
  # virtualisation.containers.enable = true;
  # virtualisation = {
  #   podman = {
  #     enable = true;

  #     # Create a `docker` alias for podman, to use it as a drop-in replacement
  #     dockerCompat = true;

  #     # Required for containers under podman-compose to be able to talk to each other.
  #     defaultNetwork.settings.dns_enabled = true;
  #   };
  # };

  # xdg-desktop-portal-hyprland
  # # Next six lines courtesy of Jennifer Darlene on 22 Jan 2024 to get basic Hyprland working
  # programs.hyprland = {
  #   enable = true;
  #   xwayland.enable = true; # allow x11 applications
  # };
  # programs.sway.enable = true;
  # console.useXkbConfig = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    localBinInPath = true; # Python support
    systemPackages = with pkgs; [
      (neovim.overrideAttrs (old: {nativeBuildInputs = old.nativeBuildInputs ++ [wl-clipboard];}))
      btop
      curl
      fd
      git
      git-lfs
      helix
      jq
      killall
      lazygit
      lf
      mlocate
      ncdu
      nnn
      parallel
      ripgrep
      rsync
      starship
      tmux
      tree
      vim
      wget
      # dive # Docker image explorer
      # gemini-cli
      # podman
      # podman-compose
      # podman-desktop
      # podman-tui
      # wineWowPackages.waylandFull # native wayland support (unstable)

      # # Next ten lines courtest of Jennifer Darlene on 22 Jan 2024 to get basic Hyprland working
      # waybar # status bar
      # mako # notification daemon
      # libnotify # for mako
      # swww # wallpaper daemon
      # kitty # terminal
      # rofi-wayland # wl equiv of rofi app launcher, window switcher ...
      # networkmanagerapplet # tray applet for network manager -- nm-applet
      # grim # screenshot utility
      # grimblast # grim helper
      # udiskie # automount removable media
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable OpenGL
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      # Modesetting is required.
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      # Enable this if you have graphical corruption issues or application crashes after waking
      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
      # of just the bare essentials.
      powerManagement.enable = false;

      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module (not to be confused with the
      # independent third-party "nouveau" open source driver).
      # Support is limited to the Turing and later architectures. Full list of
      # supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      open = true;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  fileSystems."/media/usb" = {
    device = "/dev/disk/by-uuid/a0ff5645-3695-4a32-9917-51d98d453d21"; # or …by-label/USBDISK
    fsType = "vfat"; # ext4, exfat, ntfs, …
    options = [
      "nofail" # don’t drop to emergency shell if absent
      "x-systemd.automount" # mount on first access instead of at boot
    ];
  };

  security.pki.certificateFiles = [
    ./certs/freeipa.crt
    ./certs/pihole.crt
    ./certs/proxmox.crt
  ];
}
