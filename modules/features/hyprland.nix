_: {
  flake.modules.nixos.hyprland = {
    lib,
    main-user,
    pkgs,
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
        command = "${pkgs.hyprland}/bin/Hyprland";
        user = main-user;
      };
    };
  };
}
