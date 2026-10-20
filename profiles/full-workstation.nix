{den, ...}: {
  den.aspects.full-workstation = {
    includes = with den.aspects; [kde-workstation work-communication development-lab gamedev-forge gaming media-production whatpulse full-workstation-apps];
  };
}
