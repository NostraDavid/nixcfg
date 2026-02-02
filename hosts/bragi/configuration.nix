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
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/boot.nix
    ../../modules/location.nix
    ../../modules/i18n.nix
    ../../modules/keyboard.nix
    ../../modules/storage_optimization.nix
    inputs.home-manager.nixosModules.home-manager
    (import ../../modules/home-manager.nix {inherit hostname main-user inputs;})
  ];
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    cores = 10;
    max-jobs = lib.mkForce 10;
  };

  system.stateVersion = "25.05";

  networking = {
    hostName = hostname;
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Enable networking
    networkmanager.enable = true;
  };

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
    options = "compose:rctrl";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.

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
        # packages
      ];
    };
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "david";

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
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
}
