{den, ...}: {
  den.aspects.kde-workstation = {
    includes = with den.aspects; [workstation-base plasma kde-runtime];
  };
}
