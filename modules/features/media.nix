{config, ...}: {
  flake.modules = {
    nixos.media = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.media
      ];
    };
    nixos.media-extra = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.media-extra
      ];
    };
    homeManager.media = ../home/media.nix;
    homeManager.media-extra = ../home/media-extra.nix;
  };
}
