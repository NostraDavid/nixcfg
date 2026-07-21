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

    security.pam.services.lightdm.kwallet.enable = true;

    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.i3
    ];
  };

  flake.modules.homeManager.i3 = {
    lib,
    pkgs,
    ...
  }: let
    showDesktop = pkgs.writeShellScriptBin "i3-show-desktop" ''
      current_workspace="$(${pkgs.i3}/bin/i3-msg -t get_workspaces | ${lib.getExe pkgs.jq} -r '.[] | select(.focused).name')"

      if [ "$current_workspace" = "__desktop" ]; then
        exec ${pkgs.i3}/bin/i3-msg workspace back_and_forth
      else
        exec ${pkgs.i3}/bin/i3-msg 'workspace __desktop'
      fi
    '';
  in {
    home.packages = with pkgs; [
      brightnessctl
      dmenu
      ghostty
      i3lock
      i3status
      kdePackages.dolphin
      kdePackages.spectacle
      kdePackages.kwallet
      networkmanagerapplet
      pavucontrol
      showDesktop
    ];

  };
}
