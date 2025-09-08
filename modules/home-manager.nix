{
  hostname,
  main-user,
  inputs,
  ...
}: {
  home-manager.backupFileExtension = "hm.bak";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${main-user} = {
    imports = [
      ./dotfiles.nix
      ./programs.nix
    ];

    _module.args = { inherit inputs; };

    programs.home-manager.enable = true;
    home.username = main-user;
    home.homeDirectory = "/home/${main-user}";
    home.stateVersion = "25.05";
  };
}
