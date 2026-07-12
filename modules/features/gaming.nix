{config, ...}: {
  flake.modules.nixos.gaming = {main-user, ...}: {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    virtualisation.waydroid.enable = true;

    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.gaming
    ];
  };
  flake.modules.homeManager.gaming = ../home/gaming.nix;
}
