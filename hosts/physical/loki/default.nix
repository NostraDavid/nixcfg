{
  den,
  constructors,
  lokiSpec,
  ...
}: let
  spec =
    {
      username = "david";
      hostname = "loki";
    }
    // lokiSpec;
  homeDirectory = spec.homeDirectory or "/Users/${spec.username}";
in {
  den.hosts.aarch64-darwin.loki = {
    hostName = spec.hostname;
    aspect = den.aspects.host-loki;
    instantiate = constructors.darwin lokiSpec;
    users.${spec.username} = {
      classes = [
        "homeManager"
      ];
      aspect.includes = [
        den.batteries.host-aspects
      ];
    };
  };
  den.aspects.host-loki = {
    includes = with den.aspects; [
      darwin-keyboard
      portable-home
    ];
    darwin = {pkgs, ...}: {
      homebrew.brews = [
        "libomp" # OpenMP runtime for Databricks
      ];
      homebrew.casks = [
        "alfred"
        "chatgpt"
        "iterm2"
        "jan"
        "vorssaint"
      ];
      environment.shells = [
        pkgs.bashInteractive
      ];
      networking.hostName = spec.hostname;
      system = {
        primaryUser = spec.username;
        stateVersion = 7;
      };
      users.users.${spec.username} = {
        home = homeDirectory;
        shell = pkgs.bashInteractive;
      };
      programs.bash.enable = true;
    };
    homeManager = {
      local,
      pkgs,
      unstable,
      ...
    }: {
      home.packages = [
        local.mlx-harness
        local.pandacode
        pkgs.jdk17
        unstable.github-copilot-cli
        unstable.raycast
      ];
      programs.home-manager.enable = true;
      home = {
        inherit (spec) username;
        inherit homeDirectory;
        stateVersion = "25.11";
      };
    };
  };
}
