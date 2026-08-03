{config, ...}: {
  flake.modules.nixos.kde-workstation = {
    lib,
    local,
    main-user,
    stable,
    ...
  }: {
    imports = with config.flake.modules.nixos; [
      workstation-base
      plasma
    ];

    services.displayManager = {
      sddm = {
        enable = true;
        wayland.enable = false;
        theme = "Win11OS-dark";
        settings.Wayland.SessionDir = "/etc/xdg/wayland-sessions";
        package = lib.mkDefault stable.kdePackages.sddm;
        extraPackages = [
          stable.qt6.qtdeclarative
          stable.qt6.qt5compat
          stable.qt6.qtsvg
        ];
      };
      defaultSession = "plasma";
    };

    environment.systemPackages = [
      local.win11-icon-theme
      local.win11os-kde
    ];

    users.users.${main-user}.packages = [];
  };
}
