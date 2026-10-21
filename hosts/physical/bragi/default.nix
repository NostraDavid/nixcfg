{
  den,
  constructors,
  inputs,
  ...
}: {
  den.hosts.x86_64-linux.bragi = {
    aspect = den.aspects.host-bragi;
    instantiate = constructors.nixos {
      hostname = "bragi";
      homeManager = true;
    };
    users.david = {
      classes = [
        "homeManager"
      ];
      aspect.includes = [
        den.batteries.host-aspects
      ];
    };
  };

  den.aspects.host-bragi = {
    includes = with den.aspects; [
      codex-browser
      desktop-base
      hyprland
      keyboard
    ];
    nixos = {
      lib,
      stable,
      ...
    }: {
      imports = [
        ./hardware-configuration.nix
      ];

      nix.settings = {
        cores = 10;
        keep-derivations = lib.mkForce false;
        keep-outputs = lib.mkForce false;
        max-jobs = lib.mkForce 10;
        min-free = 2 * 1024 * 1024 * 1024;
        max-free = 8 * 1024 * 1024 * 1024;
      };
      nix.gc.options = lib.mkForce "--delete-older-than 7d";
      networking.hostName = "bragi";

      system.stateVersion = "25.05";

      boot = {
        kernelPackages = stable.linuxPackages_latest;
        loader.grub.configurationLimit = 3;
      };

      services.xserver.xkb.options = "grp:win_space_toggle";

      programs.firefox = {
        enable = true;
        package = stable.firefox-esr;
      };
    };
    homeManager = {
      config,
      repoRoot,
      ...
    }: {
      home.file.".local/bin/zellij-workspace".source = config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/ndtk/.local/bin/zellij-workspace.py";
      imports = [
        # These integrations declare options; host features select their settings.
        inputs.plasma-manager.homeModules.plasma-manager
        inputs.codex-desktop-linux.homeManagerModules.default
      ];
      programs.home-manager.enable = true;
      home = {
        username = "david";
        homeDirectory = "/home/david";
        stateVersion = "25.05";
      };
    };
  };
}
