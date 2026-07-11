{config, ...}: {
  flake.modules.nixos.keyboard = {main-user, ...}: {
    imports = [../keyboard.nix];
    home-manager.users.${main-user}.imports = [
      config.flake.modules.homeManager.keyboard
    ];
  };
  flake.modules.homeManager.keyboard = ../home/keyboard.nix;
}
