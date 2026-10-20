{den, ...}: {
  den.aspects.i3-workstation = {
    includes = with den.aspects; [
      i3
      workstation-base
    ];
  };
}
