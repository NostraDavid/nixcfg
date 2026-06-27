{
  main-user,
  inputs,
  hostname,
  ...
}: let
  hostPrograms = ../programs + "/${hostname}.nix";
in {
  home-manager = {
    backupFileExtension = "hm.bak";
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${main-user} = {
      imports = [
        inputs.plasma-manager.homeModules.plasma-manager
        inputs.codex-desktop-linux.homeManagerModules.default
        ./kde-shared.nix
        ./dotfiles.nix
        ./keyboard-home.nix
        ../programs/shared.nix
        hostPrograms
      ];

      _module.args = {inherit inputs;};

      programs.home-manager.enable = true;
      home = {
        username = main-user;
        homeDirectory = "/home/${main-user}";
        stateVersion = "25.05";
      };
    };
  };
}
