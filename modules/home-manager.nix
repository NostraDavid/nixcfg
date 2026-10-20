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
    extraSpecialArgs = {inherit inputs;};
    users.${main-user} = {
      imports = [
        ./home/nix-index.nix
        ./home/development/worktrunk.nix
        inputs.plasma-manager.homeModules.plasma-manager
        inputs.codex-desktop-linux.homeManagerModules.default
      ];

      # Home Manager reuses the exact package sets configured by NixOS.
      _module.args = {inherit hostname local repoRoot stable unstable;};

      programs.home-manager.enable = true;
      home = {
        packages = [
          unstable.actionlint
          unstable.hurl
          unstable.lnav
          unstable.nix-index
          unstable.nix-tree
          unstable.nvd
          unstable.sqruff
          unstable.watchexec
        ];
        username = main-user;
        homeDirectory = "/home/${main-user}";
        stateVersion = "25.05";
      };
    };
  };
}
