{
  main-user,
  stable,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  networking = {
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
    libinput = {
      enable = true;
      touchpad.naturalScrolling = true;
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

  environment.localBinInPath = true;

  # Prefer outlines for applications such as VS Code when using the unsized names.
  fonts.fontconfig.localConf = ''
    <fontconfig>
    <alias binding="strong">
      <family>Tamzen</family>
      <prefer><family>Tamzen7x14 OTF</family></prefer>
    </alias>
    <alias binding="strong">
      <family>TamzenForPowerline</family>
      <prefer><family>TamzenForPowerline7x14 OTF</family></prefer>
    </alias>
    </fontconfig>
  '';

  fonts.packages = [
    stable.monocraft # Monocraft
    stable.nerd-fonts.bigblue-terminal # BigBlue Terminal Nerd Font
    stable.nerd-fonts.iosevka # Iosevka Nerd Font, Iosevka Nerd Font Mono
    stable.nerd-fonts.jetbrains-mono # JetBrainsMono Nerd Font Mono
    stable.spleen # Spleen 6x12, Spleen 8x16, Spleen 12x24, Spleen 16x32, Spleen 32x64 (OTF)
    stable.terminus_font_ttf # Terminus (TTF)
    stable.ultimate-oldschool-pc-font-pack # IBM PC, CGA, EGA, VGA, DOS and BIOS fonts
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
