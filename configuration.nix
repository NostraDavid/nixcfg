# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.variables.EDITOR = "vim";
  environment.variables.VISUAL = "vim";

  networking.hostName = "odin";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nl_NL.UTF-8";
    LC_IDENTIFICATION = "nl_NL.UTF-8";
    LC_MEASUREMENT = "nl_NL.UTF-8";
    LC_MONETARY = "nl_NL.UTF-8";
    LC_NAME = "nl_NL.UTF-8";
    LC_NUMERIC = "nl_NL.UTF-8";
    LC_PAPER = "nl_NL.UTF-8";
    LC_TELEPHONE = "nl_NL.UTF-8";
    LC_TIME = "nl_NL.UTF-8";
  };

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

  services.udev.extraRules = ''
    # Chromium Nuphy Air rules
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="hidraw", MODE="0660"

    # Whatpulse rules
    KERNEL=="event*", NAME="input/%k", MODE="640", GROUP="input"
  '';
  users.groups.hidraw = {};
  users.groups.input = {};

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.david = {
    isNormalUser = true;
    description = "David";
    extraGroups = ["networkmanager" "wheel" "hidraw" "input"];
    packages = with pkgs; [
      kdePackages.kate
      #  thunderbird
    ];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "david";

  # enable appimage support
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  # Install GUI apps
  programs.firefox.enable = true;
  programs.thunderbird.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  programs.bash.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };

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

  services.k3s = {
    enable = true;
    manifests.nginx.content = {
      apiVersion = "v1";
      kind = "Pod";
      metadata.name = "nginx";
      spec.containers = [
        {
          name = "nginx";
          image = "nginx:1.14.2";
          ports = [ { containerPort = 80; } ];
        }
      ];
    };
  };

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
  environment.systemPackages = with pkgs; [

    ## Terminal apps
    (neovim.overrideAttrs (old: {nativeBuildInputs = old.nativeBuildInputs ++ [wl-clipboard];}))
    # dive # Docker image explorer
    # gemini-cli
    # podman
    # podman-compose
    # podman-desktop
    # podman-tui
    alejandra # nix formatter
    atuin # shell history manager
    bat
    curl
    eza
    fd # sometimes also fdfind or fd-find
    ffmpeg
    gcc
    gh # GitHub CLI
    git
    helix # Text editor (hx)
    helm
    inxi # system information tool
    jq # JSON processor
    k3d # k3s in docker
    k3s # kubes
    kakoune # Text editor
    killall # kill processes by name
    kubectl
    kdash # Kubernetes dashboard
    k9s # Kubernetes CLI tool
    lazygit
    lf # Terminal file manager
    libpcap # for Whatpulse
    mlocate # locate command
    ncdu
    nixd # nix LSP
    nnn # Terminal file manager
    ntfs3g    # NTFS driver for work.
    p7zip # 7zip command line tool
    parallel
    ripgrep # Search tool (rg)
    rsync
    ruff
    sqlfluff # SQL linter and formatter
    starship # Shell prompt
    stow # GNU Stow for managing dotfiles
    tmux
    ty # Astral type checker
    unzip
    uv # Astral project manager
    wget
    wl-clipboard # Clipboard management for Wayland
    xq-xml # XML processor
    xz # Compression tool
    yq-go # YAML processor
    yt-dlp

    ## GUI apps
    chromium
    fooyin # Music player
    fsearch
    gimp3
    gparted
    itch
    keepassxc
    legcord # Discord client
    mission-center # Task Manager
    mpv
    remmina # Remote Desktop Protocol client
    signal-desktop
    slack
    synology-drive-client
    vscode
    wezterm
    wireguard-tools
    wireguard-ui

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

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
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

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
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
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Enable USB automounting for external drives.
  boot.supportedFilesystems = [ "exfat" "ntfs" ];

  services.udisks2.enable = true;   # daemon that owns the mount
  services.gvfs.enable   = true;    # for GNOME, Thunar, etc.
  services.devmon.enable = true;    # optional: instant automount helpers

  fileSystems."/media/usb" = {
    device  = "/dev/disk/by-uuid/a0ff5645-3695-4a32-9917-51d98d453d21";   # or …by-label/USBDISK
    fsType  = "vfat";                          # ext4, exfat, ntfs, …
    options = [
      "nofail"               # don’t drop to emergency shell if absent
      "x-systemd.automount"  # mount on first access instead of at boot
    ];
  };

  security.pki.certificates = [ "-----BEGIN CERTIFICATE-----
MIIEUjCCArqgAwIBAgIBATANBgkqhkiG9w0BAQsFADA6MRgwFgYDVQQKDA9QT1dF
UkxBTi5FTVBJUkUxHjAcBgNVBAMMFUNlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0y
NTAxMTIxMjI2NDVaFw00NTAxMTIxMjI2NDVaMDoxGDAWBgNVBAoMD1BPV0VSTEFO
LkVNUElSRTEeMBwGA1UEAwwVQ2VydGlmaWNhdGUgQXV0aG9yaXR5MIIBojANBgkq
hkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA3C+1lT44K2YiJC2omyU6Y2QKOxhsn4FG
OIevWClkVOQerP1IkPx3aPl7aH2+e4yy144WhjzMue36n9jy8SvFOmR6ud2a1D0Q
NyILrTBxp73Zsr5pF6Mhf7DoxOVlQ3IVoxPSesI6nNzg9nVcsdS+wo8NgA9+YQHX
GyVtQmsFN7iNs0TjLAqCqoIgrhlL4NRvDXhQg1uPXjczalUZt1M4Vcj8i6gfCsPG
8BLeuYoKsQP8xV7J+9LEjntGmBWCKFPVfQ9MXA/H1tIj2qnO200gHtT0sWioxWtZ
xStF+Wq8Gz7p/x0hulEcS796a3FxNI32iEY8+0EFlOJcQ7laPU5TJ92DcmBDXX4y
H+LgJ/hoCjsaxB7C52lRcBfNqsDphh+okgctMVFwC9wK4Zy/IhKcvmL+cUpPu1ov
EAxYPPtnnCsRgYseoEfgdtz3rnFdAQoo1qUwiBwl8jD2Ovnhk23T4l+AwEs0ErGD
WFcM93sCD61y1Db2TRqxz4DgGi/lXtvXAgMBAAGjYzBhMB0GA1UdDgQWBBQawHUL
HNGT2MPIBM6cg4Jgp8QVmTAfBgNVHSMEGDAWgBQawHULHNGT2MPIBM6cg4Jgp8QV
mTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBxjANBgkqhkiG9w0BAQsF
AAOCAYEAXZOA0urWFS4rQkM8laOtzEGf48BJ/ToqT3py8Br+RvftAbRTinUVptmf
aYGP6PbBislVEO3KLW7c3Qut8RfR0CBrTux1Mz8YGj89YXsW3avuDrchVKPKV1ik
bmSJsdtFW72RHpdhQmvnKmzmjZjXcMy+V+Uzu1qooQo+z1BYYsD8qY6YeNrliu0B
39odeq46ClEhN38mdTz//tDB0sNpKwLNISQffILZfuSpbFYGDvdDKl40yRV6RKKk
sXMrk1VA43Plh0PdgAvGBx8UxP0cBIPwMnXsYtJL2B8CEN+ecbjWuks8RzgZnJ69
2BphXVMcdOK1Oi3C4O5YdwTGPwXFFtHqP9Hek5b+ajdpQujb+jPyD8cHm3Y5CoLc
34RXPMLPMr3qMCWgHdlkIHWahayT956hjMlu5h7hYnd3cMMgEtDwiFoq2/V8sq8p
JDraZyr6o/T+hHfzPV7GlTHcQRyV+vKGCHmNzxHMFDNnO91Cqzd16GOLG/3vzfMW
p9yXccCM
-----END CERTIFICATE-----" ];
}
