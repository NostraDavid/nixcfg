_: {
  den.aspects.gaming = {
    nixos.imports = [
      {
        programs.steam = {
          enable = true;
          remotePlay.openFirewall = true;
          dedicatedServer.openFirewall = true;
          localNetworkGameTransfers.openFirewall = true;
        };

        virtualisation.waydroid.enable = true;
      }
    ];
    homeManager = {
      imports = [
        ./_home.nix
      ];
    };
  };
}
