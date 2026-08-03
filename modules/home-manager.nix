{
  hostname,
  main-user,
  inputs,
  local,
  repoRoot,
  stable,
  unstable,
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

      # Home Manager reuses the exact package sets configured by NixOS.
      _module.args = {inherit hostname inputs local repoRoot stable unstable;};

      programs.home-manager.enable = true;
      home = {
        username = main-user;
        homeDirectory = "/home/${main-user}";
        stateVersion = "25.05";
      };
    };
  };
}
