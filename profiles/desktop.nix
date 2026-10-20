{den, ...}: {
  den.aspects.desktop = {
    includes = with den.aspects; [
      browsers
      communication
      containers
      desktop-apps
      desktop-base
      development
      dotfiles
      keyboard
      media
      plasma
      terminal
    ];
  };
}
