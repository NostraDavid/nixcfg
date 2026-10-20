{den, ...}: {
  den.aspects.workstation-base = {
    includes = with den.aspects; [desktop-base browsers communication containers desktop-apps development dotfiles keyboard media terminal workstation-runtime];
  };
}
