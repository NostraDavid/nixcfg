{den, ...}: {
  den.aspects.workstation = {
    includes = with den.aspects; [workstation-extra];
  };
}
