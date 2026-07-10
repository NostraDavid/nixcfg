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
        desktop
      ];

      nix.settings = {
        cores = 10;
        max-jobs = lib.mkForce 10;
      };
      system.stateVersion = "25.05";

      boot.kernelPackages = pkgs.linuxPackages_latest;

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
