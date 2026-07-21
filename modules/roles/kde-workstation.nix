{config, ...}: {
  flake.modules.nixos.kde-workstation = {
    main-user,
    pkgs,
    ...
  }: {
    imports = with config.flake.modules.nixos; [
      workstation-base
      plasma
    ];

    services.displayManager = {
      sddm = {
        wayland.enable = false;
        settings.Wayland.SessionDir = "/etc/xdg/wayland-sessions";
      };
      defaultSession = "plasma";
    };

    users.users.${main-user}.packages = with pkgs; [
      kdePackages.kate
    ];
  };
}
