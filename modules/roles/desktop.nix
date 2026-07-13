{config, ...}: {
  flake.modules.nixos.desktop-base = {
    inputs,
    hostname,
    main-user,
    pkgs,
    repoRoot,
    ...
  }: {
    imports = [
      ../boot.nix
      ../location.nix
      ../i18n.nix
      ../storage_optimization.nix
      inputs.home-manager.nixosModules.home-manager
      (import ../home-manager.nix {inherit hostname main-user inputs repoRoot;})
    ];

    nix.settings.experimental-features = ["nix-command" "flakes"];

    networking = {
      hostName = hostname;
      networkmanager.enable = true;
      hosts = {};
    };

    time.timeZone = "Europe/Amsterdam";

    services = {
      xserver = {
        enable = true;
        xkb = {
          layout = "us,runic";
          variant = ",basic";
        };
      };
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
    };

    security.rtkit.enable = true;

    users = {
      groups = {
        hidraw = {};
        input = {};
      };
      users.${main-user} = {
        isNormalUser = true;
        description = "";
        extraGroups = ["networkmanager" "wheel" "hidraw" "input"];
      };
    };

    nixpkgs.config.allowUnfree = true;

    environment.localBinInPath = true;

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  flake.modules.nixos.desktop = {
    imports = with config.flake.modules.nixos; [
      desktop-base
      browsers
      communication
      containers
      desktop-apps
      development
      dotfiles
      keyboard
      media
      plasma
      terminal
    ];
  };
}
