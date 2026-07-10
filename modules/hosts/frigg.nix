{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.frigg = mkHost {
    hostname = "frigg";
    module = {lib, ...}: {
      imports = with config.flake.modules.nixos; [
        ../../hosts/frigg/hardware-configuration.nix
        workstation
        laptop
      ];

      nix.settings = {
        cores = lib.mkForce 4;
        max-jobs = lib.mkForce 2;
      };
      systemd.services.nix-daemon.serviceConfig.CPUQuota = "400%";

      system.stateVersion = "25.05";
    };
  };
}
