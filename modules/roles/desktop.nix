{config, ...}: {
  flake.modules.nixos.desktop = {
    imports = with config.flake.modules.nixos; [
      desktop-base
      browsers
      communication
      containers
      desktop-apps
      development
      dotfiles
      keyboard
      media
      plasma
      terminal
    ];
  };
}
