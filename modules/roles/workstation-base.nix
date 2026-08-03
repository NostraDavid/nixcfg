{config, ...}: {
  flake.modules.nixos.workstation-base = {
    lib,
    stable,
    ...
  }: {
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
      terminal
    ];

    services = {
      xserver.xkb.options = lib.mkDefault "grp:win_space_toggle";
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

    programs = {
      appimage = {
        enable = true;
        binfmt = true;
      };
      nix-ld = {
        enable = true;
        libraries = [stable.freetype];
      };
      firefox = {
        enable = true;
        package = stable.firefox-esr;
        policies.Certificates.ImportEnterpriseRoots = true;
        languagePacks = [
          "en-US"
          "nl"
        ];
      };
      thunderbird.enable = true;
      starship.enable = false;
    };

    environment.systemPackages = [
      stable.ntfs3g # NTFS filesystem driver and administration tools
    ];

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
