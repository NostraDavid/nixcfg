{
  main-user,
  inputs,
  ...
}: {
  home-manager = {
    backupFileExtension = "hm.bak";
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${main-user} = {
      imports = [
        inputs.pi.homeModules.default
        inputs.plasma-manager.homeModules.plasma-manager
        inputs.codex-desktop-linux.homeManagerModules.default
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
