{config, ...}: {
  flake.modules = {
    nixos.media = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.media
      ];
    };
    homeManager.media = ../home/media.nix;
    homeManager.media-wodan = ../home/wodan-media.nix;
  };
}
