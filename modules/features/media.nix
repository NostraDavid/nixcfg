{config, ...}: {
  flake.modules = {
    nixos.media = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.media
      ];
    };
    nixos.media-production = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.media-production
      ];
    };
    homeManager.media.imports = [
      ../home/media/apps.nix
      ../home/media/tools.nix
    ];
    homeManager.media-production = ../home/media/production.nix;
  };
}
