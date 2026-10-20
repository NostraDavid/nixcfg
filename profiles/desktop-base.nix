{den, ...}: {
  den.aspects.desktop-base = {
    includes = with den.aspects; [
      boot
      desktop-runtime
      i18n
      interactive
      location
      storage-optimization
    ];
  };
}
