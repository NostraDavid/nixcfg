{config, ...}: {
  flake.modules.nixos.niri = {
    lib,
    main-user,
    pkgs,
    ...
  }: {
    programs.niri.enable = true;

    services.xserver.enable = lib.mkForce false;

    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.niri}/bin/niri-session";
        user = main-user;
      };
    };

    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.niri
    ];
  };

  flake.modules.homeManager.niri = {pkgs, ...}: {
    home.packages = with pkgs; [
      alacritty
      brightnessctl
      fuzzel
      playerctl
      swaylock
      waybar
    ];
  };
}
