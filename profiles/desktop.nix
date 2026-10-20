{den, ...}: {
  den.aspects.desktop = {
    includes = with den.aspects; [desktop-base browsers communication containers desktop-apps development dotfiles keyboard media plasma terminal];
  };
}
