{config, ...}: {
  flake.modules.nixos.wodan-home = {main-user, ...}: {
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.browsers-wodan
      config.flake.modules.homeManager.communication-wodan
      config.flake.modules.homeManager.development-wodan
      config.flake.modules.homeManager.desktop-apps-wodan
      config.flake.modules.homeManager.media-wodan
      config.flake.modules.homeManager.wodan
    ];
  };
  flake.modules.homeManager.wodan = ../home/wodan.nix;
}
