{config, ...}: {
  flake.modules.nixos.kde-workstation = {
    lib,
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
        enable = true;
        wayland.enable = false;
        theme = "Win11OS-dark";
        settings.Wayland.SessionDir = "/etc/xdg/wayland-sessions";
        package = lib.mkDefault pkgs.kdePackages.sddm;
        extraPackages = with pkgs; [
          qt6.qtdeclarative
          qt6.qt5compat
          qt6.qtsvg
        ];
      };
      defaultSession = "plasma";
    };

    environment.systemPackages = with pkgs; [
      win11-icon-theme
      win11os-kde
    ];

    users.users.${main-user}.packages = with pkgs; [];
  };
}
