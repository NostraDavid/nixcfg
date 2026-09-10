_: {
  flake.modules.nixos.desktop-base = {
    inputs,
    hostname,
    local,
    main-user,
    repoRoot,
    stable,
    unstable,
    ...
  }: {
    imports = [
      ../boot.nix
      ../location.nix
      ../i18n.nix
      ../storage_optimization.nix
      inputs.home-manager.nixosModules.home-manager
      (import ../home-manager.nix {inherit hostname main-user inputs local repoRoot stable unstable;})
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
      local.creep2 # creep2
      local.pico-8-font # PICO-8
      local.tamzen-otf # Tamzen7x14 OTF, TamzenForPowerline7x14 OTF; also 5x9, 6x12, 7x13, 8x15, 8x16, 10x20
      stable.anakron # ANAKRON, ANAKRON Nerd Font Mono
      stable.cozette # CozetteVector, CozetteCrossedSevenVector
      stable.creep # creep
      stable.kirsch # kirsch, Kirsch Nerd Font Mono
      stable.nerd-fonts.departure-mono # DepartureMono Nerd Font Mono
      stable.nerd-fonts.gohufont # GohuFont 11 Nerd Font Mono, GohuFont 14 Nerd Font Mono
      stable.nerd-fonts.jetbrains-mono # JetBrainsMono Nerd Font Mono
      stable.nerd-fonts.profont # ProFontWindows Nerd Font Mono, ProFont IIx Nerd Font Mono
      stable.nerd-fonts.proggy-clean-tt # ProggyClean Nerd Font Mono
      stable.nerd-fonts.terminess-ttf # Terminess Nerd Font Mono
      stable.scientifica # scientifica
      stable.spleen # Spleen 6x12, Spleen 8x16, Spleen 12x24, Spleen 16x32, Spleen 32x64 (OTF)
      stable.tamzen # Tamzen, TamzenForPowerline (bitmap; aliases above prefer OTF)
      stable.terminus_font_ttf # Terminus (TTF)
    ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
