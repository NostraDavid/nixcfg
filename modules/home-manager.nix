{
  hostname,
  main-user,
  ...
}: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${main-user} = {
    imports = [
      ./dotfiles.nix
      ./programs.nix
    ];

    programs.home-manager.enable = true;
    home.username = main-user;
    home.homeDirectory = "/home/${main-user}";
    home.stateVersion = "25.05";
  };
}
