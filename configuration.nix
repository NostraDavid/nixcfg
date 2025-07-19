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
    /etc/nixos/hardware-configuration.nix
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # Enable USB automounting for external drives.
    supportedFilesystems = ["exfat" "ntfs"];
  };

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = ["nix-command" "flakes"];

  networking = {
    hostName = "odin";

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

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocales = [
      "nl_NL.UTF-8/UTF-8"
      "en_DK.UTF-8/UTF-8"
      "en_US/ISO-8859-1"
    ];
    extraLocaleSettings = {
      # https://www.man7.org/linux/man-pages/man7/locale.7.html
      # LC_ALL = "en_US.UTF-8";

      # Address format (street, city, postal code)
      LC_ADDRESS = "nl_NL.UTF-8";
      # Alphabetical sorting order
      LC_COLLATE = "en_US.UTF-8";
      # Character classification (letters, numbers, etc.)
      LC_CTYPE = "en_US.UTF-8";
      # Metadata about the locale
      LC_IDENTIFICATION = "nl_NL.UTF-8";
      # Currency format (€, comma for decimal)
      LC_MONETARY = "nl_NL.UTF-8";
      # System and application language
      LC_MESSAGES = "en_US.UTF-8";
      # Measurement units (metric system)
      LC_MEASUREMENT = "nl_NL.UTF-8";
      # Name formatting conventions
      LC_NAME = "nl_NL.UTF-8";
      # Number format (comma for decimal)
      LC_NUMERIC = "en_US.UTF-8";
      # Default paper size (A4)
      LC_PAPER = "nl_NL.UTF-8";
      # Telephone number format
      LC_TELEPHONE = "nl_NL.UTF-8";
      # Date and time format (YYYY-MM-DD)
      LC_TIME = "en_DK.UTF-8";
    };
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services = {
    xserver.enable = true;

    # Enable the KDE Plasma Desktop Environment.
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;

    # Configure keymap in X11
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Enable CUPS to print documents.
    printing.enable = true;

    # NuPhy Air75HE, and Whatpulse support
    udev.extraRules = ''
      # Chromium Nuphy Air rules
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="hidraw", MODE="0660"

      # Whatpulse rules
      KERNEL=="event*", NAME="input/%k", MODE="640", GROUP="input"
    '';

    # Enable touchpad support (enabled default in most desktopManager).
    # xserver.libinput.enable = true;

    # Enable automatic login for the user.
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "david";
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
    # Load nvidia driver for Xorg and Wayland
    xserver.videoDrivers = ["nvidia"];

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
    users.david = {
      # shell = pkgs.
      isNormalUser = true;
      description = "David";
      # hidraw and input for Whatpulse and NuPhy Air75HE support (IIRC)
      extraGroups = ["networkmanager" "wheel" "hidraw" "input"];
      packages = with pkgs; [
        kdePackages.kate
        #  thunderbird
      ];
    };
  };

  programs = {
    # enable appimage support, for Whatpulse and other AppImages
    appimage = {
      enable = true;
      binfmt = true;
    };
    nix-ld = {
      # https://wiki.nixos.org/wiki/Nix-ld
      enable = true;
      libraries = with pkgs; [
        freetype
      ];
    };
    bash = {
      shellAliases = {
        vi = "nvim";
        vim = "nvim";
      };
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
    starship = {
      enable = true;

      settings = {
        "$schema" = "https://starship.rs/config-schema.json";

        format = "$git_branch$git_commit$git_state$git_metrics$git_status$directory$python$status$character";

        add_newline = false;
        command_timeout = 500;
        palette = "powerline_status";

        palettes.powerline_status = {
          term_bg = "#1e1e1e";
          dark_bg = "#303030";
          light_bg = "#585858";
          pyth = "#26b446";
          stat = "#d75f00";

          orange = "#ffaf00";
          darkblue = "#005faf";
          brightestorange = "#ffaf00";
          mediumorange = "#ff8700";
        };

        git_branch = {
          style = "bg:dark_bg";
          format = "[$symbol $branch]($style)";
          symbol = "";
          truncation_length = 12;
          truncation_symbol = "…";
          only_attached = true;
        };

        git_commit = {
          style = "purple bg:dark_bg";
          format = "[ $tag$hash]($style)";
          tag_symbol = "🔖 ";
          tag_disabled = false;
          only_detached = true;
        };

        git_state = {
          style = "bg:dark_bg";
          format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
        };

        git_status = {
          style = "bg:dark_bg";
          format = "[ $conflicted$stashed$deleted$renamed$modified$typechanged$staged$untracked$ahead_behind$ahead_count$behind_count ]($style)";
          up_to_date = "";
          behind = "[↓ \${count}](fg:white bg:prev_bg) ";
          ahead = "[↑ \${count}](fg:white bg:prev_bg) ";
          staged = "[● \${count}](fg:green bg:prev_bg) ";
          deleted = "[✖ \${count}](fg:red bg:prev_bg) ";
          renamed = "[➜ \${count}](fg:purple bg:prev_bg) ";
          stashed = "[⚑ \${count}](fg:darkblue bg:prev_bg) ";
          untracked = "[… \${count}](fg:brightestorange bg:prev_bg ) ";
          modified = "[✚ \${count}](fg:mediumorange bg:prev_bg) ";
          conflicted = "[═ \${count}](fg:yellow bg:prev_bg) ";
          diverged = "⇕ \${ahead_count}⇣\${behind_count}";
        };

        directory = {
          style = "bg:light_bg";
          format = "[](fg:prev_bg fg:light_bg bg:light_bg)[ $path ]($style)";
          truncation_length = 3;
          truncation_symbol = "…  ";
          truncate_to_repo = false;
          read_only = " 󰌾";
          use_os_path_sep = true;
          substitutions = {
            "Documents" = "󰈙 ";
            "Downloads" = " ";
            "Music" = " ";
            "Pictures" = " ";
          };
        };

        python = {
          symbol = "";
          style = "bg:pyth";
          format = "[](fg:prev_bg bg:pyth)[ $symbol $version ]($style)";
        };

        status = {
          style = "bg:stat";
          format = "[](fg:prev_bg bg:stat)[$int]($style)";
          disabled = false;
        };

        character = {
          success_symbol = "[](fg:prev_bg)";
          error_symbol = "[](fg:stat)";
        };

        time = {
          disabled = false;
          time_format = "%R";
          style = "bg:term_bg";
          format = "[$time]($style) ";
        };

        os = {
          style = "bg:#9A348E";
          disabled = true;
        };

        package = {
          disabled = true;
          symbol = "󰏗 ";
        };

        battery = {
          full_symbol = ":battery:";
          charging_symbol = ":zap: ";
          discharging_symbol = ":skull: ";
          empty_symbol = ":low_battery: ";
        };

        # Language modules (shared style and format)
        c = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        elixir = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        elm = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        golang = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        gradle = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        haskell = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        java = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        julia = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        nodejs = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        nim = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        rust = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };
        scala = {
          style = "bg:#86BBD8";
          format = "[ $symbol ($version) ]($style)";
        };

        gradle.symbol = " ";
        c.symbol = " ";
        elixir.symbol = " ";
        elm.symbol = " ";
        golang.symbol = " ";
        haskell.symbol = " ";
        java.symbol = " ";
        julia.symbol = " ";
        nodejs.symbol = "";
        nim.symbol = "󰆥 ";
        rust.symbol = "";
        scala.symbol = " ";

        docker_context = {
          symbol = " ";
          style = "bg:#06969A";
          format = "[ $symbol $context ]($style)";
        };

        # Symbols
        aws.symbol = "  ";
        buf.symbol = " ";
        cmake.symbol = " ";
        conda.symbol = " ";
        crystal.symbol = " ";
        dart.symbol = " ";
        fennel.symbol = " ";
        fossil_branch.symbol = " ";
        guix_shell.symbol = " ";
        haxe.symbol = " ";
        hg_branch.symbol = " ";
        hostname.ssh_symbol = " ";
        kotlin.symbol = " ";
        lua.symbol = " ";
        memory_usage.symbol = "󰍛 ";
        meson.symbol = "󰔷 ";
        nix_shell.symbol = " ";
        ocaml.symbol = " ";
        perl.symbol = " ";
        php.symbol = " ";
        pijul_channel.symbol = " ";
        rlang.symbol = "󰟔 ";
        ruby.symbol = " ";
        swift.symbol = " ";
        zig.symbol = " ";

        os.symbols = {
          NixOS = " ";
          Macos = " ";
          Ubuntu = " ";
          Debian = " ";
          Fedora = " ";
          Arch = " ";
          Windows = "󰍲 ";
        };
      };
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
    thunderbird.enable = true;
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
    variables = {
      EDITOR = "vim";
      VISUAL = "vim";
    };
    systemPackages = with pkgs; [
      ## Terminal apps
      (neovim.overrideAttrs (old: {nativeBuildInputs = old.nativeBuildInputs ++ [wl-clipboard];}))
      # dive # Docker image explorer
      # gemini-cli
      # podman
      # podman-compose
      # podman-desktop
      # podman-tui
      # wineWowPackages.waylandFull # native wayland support (unstable)
      alejandra # nix formatter
      atuin # shell history manager
      bat
      btop # Resource monitor
      curl
      direnv # Environment variable manager for dev
      dnsutils # `dig` + `nslookup`
      eza
      fd # sometimes also fdfind or fd-find
      ffmpeg
      freetype
      gcc
      gh # GitHub CLI
      git
      git-lfs # Git Large File Storage
      helix # Text editor (hx)
      helm
      home-manager # Home Manager for managing user configurations
      hyperfine # Command-line benchmarking tool
      image_optim # Image optimization tool
      inxi # system information tool
      ipcalc # it is a calculator for the IPv4/v6 addresses
      jpegoptim # JPEG image optimizer
      jq # JSON processor
      just # justcfile
      k3d # k3s in docker
      k3s # kubes
      k9s # Kubernetes CLI tool
      kakoune # Text editor
      kdash # Kubernetes dashboard
      killall # kill processes by name
      kubectl
      lazygit
      lf # Terminal file manager
      libpcap # for Whatpulse
      lsof # List open files
      mlocate # locate command
      mtr # A network diagnostic tool
      ncdu
      nixd # nix LSP
      nnn # Terminal file manager
      ntfs3g # NTFS driver for work.
      optipng # PNG image optimizer
      oxipng # PNG image optimizer
      p7zip # 7zip command line tool
      parallel
      pv # Pipe viewer, useful for monitoring data through a pipe
      qalculate-qt
      ripgrep # Search tool (rg)
      rsync
      ruff
      speedcrunch
      sqlfluff # SQL linter and formatter
      starship # Shell prompt
      stow # GNU Stow for managing dotfiles
      tmux
      tree # Display directory structure in a tree-like format
      ty # Astral type checker
      unzip
      uv # Astral project manager
      wget
      winetricks
      wineWowPackages.stable # support both 32-bit and 64-bit applications
      wl-clipboard # Clipboard management for Wayland
      xq-xml # XML processor
      xz # Compression tool
      yq-go # YAML processor
      yt-dlp
      zopfli # For zopflipng; optimize PNG files

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
      loupe

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
