{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.bragi = mkHost {
    hostname = "bragi";
    module = {
      lib,
      stable,
      ...
    }: {
      imports = with config.flake.modules.nixos; [
        ../../hosts/bragi/hardware-configuration.nix
        desktop-base
        hyprland
        keyboard
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
        kernelPackages = stable.linuxPackages_latest;
        loader.grub.configurationLimit = 3;
      };

      services.xserver.xkb.options = "grp:win_space_toggle";

      programs.firefox = {
        enable = true;
        package = stable.firefox-esr;
      };
    };
  };
}
