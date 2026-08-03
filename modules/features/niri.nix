{config, ...}: {
  flake.modules.nixos.niri = {
    lib,
    main-user,
    stable,
    ...
  }: {
    programs.niri.enable = true;

    services.xserver.enable = lib.mkForce false;

    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${stable.niri}/bin/niri-session";
        user = main-user;
      };
    };

    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.niri
    ];
  };

  flake.modules.homeManager.niri = {stable, ...}: {
    home.packages = [
      stable.alacritty
      stable.brightnessctl
      stable.fuzzel
      stable.playerctl
      stable.swaylock
      stable.waybar
    ];
  };
}
