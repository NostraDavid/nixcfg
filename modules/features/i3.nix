{config, ...}: {
  flake.modules.nixos.i3 = {
    main-user,
    pkgs,
    ...
  }: {
    services = {
      displayManager = {
        autoLogin = {
          enable = true;
          user = main-user;
        };
        defaultSession = "none+i3";
      };
      xserver = {
        displayManager.lightdm.enable = true;
        windowManager.i3 = {
          enable = true;
          extraPackages = with pkgs; [
            dmenu
            i3lock
            i3status
          ];
        };
      };
    };

    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.i3
    ];
  };

  flake.modules.homeManager.i3 = {
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      brightnessctl
      dmenu
      ghostty
      i3lock
      i3status
      networkmanagerapplet
      pavucontrol
    ];

    xsession.windowManager.i3 = {
      enable = true;
      config = let
        modifier = "Mod4";
      in {
        inherit modifier;
        terminal = "ghostty";
        menu = "${pkgs.dmenu}/bin/dmenu_run -i";
        keybindings = lib.mkOptionDefault {
          "${modifier}+Shift+l" = "exec --no-startup-id ${lib.getExe pkgs.i3lock} -c 111111";
          "${modifier}+a" = "exec --no-startup-id ${lib.getExe pkgs.pavucontrol}";
          "XF86AudioLowerVolume" = "exec --no-startup-id ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute" = "exec --no-startup-id ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          "XF86AudioRaiseVolume" = "exec --no-startup-id ${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86MonBrightnessDown" = "exec --no-startup-id ${lib.getExe pkgs.brightnessctl} set 5%-";
          "XF86MonBrightnessUp" = "exec --no-startup-id ${lib.getExe pkgs.brightnessctl} set +5%";
        };
        startup = [
          {
            command = "${pkgs.networkmanagerapplet}/bin/nm-applet";
            notification = false;
          }
        ];
        bars = [
          {statusCommand = lib.getExe pkgs.i3status;}
        ];
      };
    };
  };
}
