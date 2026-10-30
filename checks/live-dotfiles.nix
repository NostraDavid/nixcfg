let
  flake = builtins.getFlake (toString ../.);
  pkgs =
    if builtins.currentSystem == "aarch64-darwin"
    then flake.darwinConfigurations.loki.pkgs
    else flake.nixosConfigurations.wodan.pkgs;
  repoRoot = builtins.getEnv "FIXTURE_DOTFILES_ROOT";
  arguments = {
    inherit (flake) inputs;
    stable = pkgs;
    unstable = pkgs;
    inherit repoRoot;
  };
  homeModules = [
    {
      home = {
        username = "fixture";
        homeDirectory = "/unused";
        stateVersion = "25.11";
      };
    }
  ];
  home = flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = arguments;
    modules =
      [
        ../features/terminal/_config.nix
      ]
      ++ homeModules;
  };
  portable = flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = arguments;
    modules =
      [
        ../features/dotfiles/_portable-dotfiles.nix
      ]
      ++ homeModules;
  };
  pi = import ../features/mcp/_pi.nix (arguments
    // {
      inherit (home) config;
      inherit (pkgs) lib;
    });
in
  pkgs.linkFarm "live-dotfile-links" (
    map (name: {
      inherit name;
      path = home.config.home.file.${name}.source;
    }) [
      ".config/alacritty/alacritty.toml"
      ".config/bat/config"
      ".config/starship.toml"
      ".config/zellij/config.kdl"
    ]
    ++ map (name: {
      inherit name;
      path = portable.config.home.file.${name}.source;
    }) [
      ".config/herdr-app/keys.json"
      ".config/herdr-app/settings.json"
    ]
    ++ map (name: {
      inherit name;
      path = pi.home.file.${name}.source;
    }) [
      ".pi/agent/settings.json"
      ".pi/agent/mcp.json"
    ]
  )
