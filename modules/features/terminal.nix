{config, ...}: {
  flake.modules = {
    nixos = {
      terminal = {main-user, ...}: {
        home-manager.users.${main-user}.imports = [
          config.flake.modules.homeManager.terminal
        ];
      };
      terminal-core = {main-user, ...}: {
        home-manager.users.${main-user}.imports = [
          config.flake.modules.homeManager.terminal-core
        ];
      };
    };
    homeManager = {
      terminal.imports = [
        config.flake.modules.homeManager.terminal-core
        ../home/terminal-packages.nix
      ];
      terminal-core = ../home/terminal.nix;
    };
  };
}
