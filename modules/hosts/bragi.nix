{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.bragi = mkHost {
    hostname = "bragi";
    module = {
      lib,
      pkgs,
      ...
    }: {
      imports = with config.flake.modules.nixos; [
        ../../hosts/bragi/hardware-configuration.nix
        i3-desktop
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
      system.stateVersion = "25.05";

      boot = {
        kernelPackages = pkgs.linuxPackages_latest;
        loader.grub.configurationLimit = 3;
      };

      services = {
        xserver.xkb.options = "grp:win_space_toggle";
        printing.enable = true;
      };

      programs.firefox = {
        enable = true;
        package = pkgs.firefox-esr;
      };

      environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";
    };
  };
}
