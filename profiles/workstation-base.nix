{den, ...}: {
  den.aspects.workstation-base = {
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
      terminal
      workstation-runtime
    ];
  };
}
