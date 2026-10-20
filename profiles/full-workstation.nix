{den, ...}: {
  den.aspects.full-workstation = {
    includes = with den.aspects; [
      development-lab
      full-workstation-apps
      gamedev-forge
      gaming
      kde-workstation
      media-production
      whatpulse
      work-communication
    ];
  };
}
