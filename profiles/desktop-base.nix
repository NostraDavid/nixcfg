{den, ...}: {
  den.aspects.desktop-base = {
    includes = with den.aspects; [boot location i18n storage-optimization interactive desktop-runtime];
  };
}
