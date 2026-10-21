{den, ...}: {
  den.aspects.desktop-base = {
    includes = with den.aspects; [
      boot
      desktop-runtime
      fonts
      i18n
      interactive
      location
      storage-optimization
    ];
  };
}
