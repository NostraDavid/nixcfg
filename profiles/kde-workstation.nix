{den, ...}: {
  den.aspects.kde-workstation = {
    includes = with den.aspects; [
      kde-runtime
      plasma
      workstation-base
    ];
  };
}
