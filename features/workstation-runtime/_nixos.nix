{
  lib,
  stable,
  ...
}: {
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
      libraries = [
        stable.freetype
      ];
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
}
