{config, ...}: {
  flake.modules.nixos.dotfiles = {main-user, ...}: {
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.dotfiles
    ];
  };
  flake.modules.homeManager.dotfiles = ../home/dotfiles.nix;
}
