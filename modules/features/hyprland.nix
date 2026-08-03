_: {
  flake.modules.nixos.hyprland = {
    lib,
    main-user,
    stable,
    ...
  }: {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    services.xserver.enable = lib.mkForce false;

    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${stable.hyprland}/bin/Hyprland";
        user = main-user;
      };
    };
  };
}
