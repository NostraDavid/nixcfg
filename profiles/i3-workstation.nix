{den, ...}: {
  den.aspects.i3-workstation = {
    includes = with den.aspects; [workstation-base i3];
  };
}
