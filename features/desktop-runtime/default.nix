_: {
  den.aspects.desktop-runtime = {
    nixos.imports = [
      ({main-user, ...}: {
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

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
            extraGroups = [
              "hidraw"
              "input"
              "networkmanager"
              "wheel"
            ];
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

        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };
      })
    ];
  };
}
