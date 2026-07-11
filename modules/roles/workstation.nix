{config, ...}: {
  flake.modules.nixos.workstation = {
    lib,
    main-user,
    pkgs,
    ...
  }: {
    imports = [config.flake.modules.nixos.desktop];

    services = {
      xserver.xkb.options = lib.mkDefault "grp:win_space_toggle";
      displayManager = {
        sddm = {
          wayland.enable = false;
          settings.Wayland.SessionDir = "/etc/xdg/wayland-sessions";
        };
        defaultSession = "plasma";
      };
      printing.enable = false;
      udev.extraRules = ''
        # Chromium Nuphy Air rules
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="hidraw", MODE="0660"

        # Whatpulse rules
        KERNEL=="event*", NAME="input/%k", MODE="640", GROUP="input"
      '';
      openssh.enable = true;
      udisks2.enable = true;
      gvfs.enable = true;
      devmon.enable = true;
    };

    users.users.${main-user}.packages = with pkgs; [
      kdePackages.kate
    ];

    programs = {
      appimage = {
        enable = true;
        binfmt = true;
      };
      nix-ld = {
        enable = true;
        libraries = with pkgs; [freetype];
      };
      firefox = {
        enable = true;
        package = pkgs.firefox-esr;
        policies.Certificates.ImportEnterpriseRoots = true;
        languagePacks = [
          "en-US"
          "nl"
        ];
      };
      thunderbird.enable = true;
      starship.enable = false;
    };

    virtualisation = {
      containers.enable = true;
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    fileSystems."/media/usb" = {
      device = "/dev/disk/by-uuid/a0ff5645-3695-4a32-9917-51d98d453d21";
      fsType = "vfat";
      options = [
        "nofail"
        "x-systemd.automount"
      ];
    };
  };
}
