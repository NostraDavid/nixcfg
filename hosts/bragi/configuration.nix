# bragi
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  lib,
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
    ../../modules/storage_optimization.nix
    inputs.home-manager.nixosModules.home-manager
    (import ../../modules/home-manager.nix {inherit hostname main-user inputs;})
  ];
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    cores = 10;
    max-jobs = lib.mkForce 10;
  };

  # Keep Nix builds from saturating all threads.
  systemd.services.nix-daemon.serviceConfig = {
    CPUQuota = "1000%";
  };

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

    hosts = {
      # related to project ctb
      "127.0.0.1" = ["mlflow.localhost"];
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # improve battery life
  powerManagement = {
    cpuFreqGovernor = "schedutil";
    powertop.enable = true;
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services = {
    xserver = {
      enable = true;
      # TODO: set a specific driver if needed (nvidia/amdgpu/intel)
      videoDrivers = ["modesetting"];
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

    # improve battery life
    power-profiles-daemon.enable = false;
    tlp = {
      enable = true;
      settings = {
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        STOP_CHARGE_THRESH_BAT0 = 95;
      };
    };

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
    libinput.enable = true;

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
    # nix-ld to enable `uv sync`
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
  };

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
  };

  # Enable common container config files in /etc/containers
  systemd.user.services.podman = {
    enable = true;
    wantedBy = ["default.target"];
  };
  virtualisation = {
    containers = {
      enable = true;
    };
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    localBinInPath = true; # Python support
    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };
    systemPackages = with pkgs; [
      # packages go here
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # List services that you want to enable:

  # Enable OpenGL
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
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
}
