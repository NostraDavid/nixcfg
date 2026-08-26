{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.frigg = mkHost {
    hostname = "frigg";
    module = {
      inputs,
      lib,
      main-user,
      local,
      ...
    }: {
      imports = with config.flake.modules.nixos; [
        ../../hosts/frigg/hardware-configuration.nix
        kde-workstation
        laptop
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen1
      ];

      nix.settings = {
        cores = lib.mkForce 4;
        max-jobs = lib.mkForce 2;
      };
      systemd.services.nix-daemon.serviceConfig.CPUQuota = "400%";

      home-manager.users.${main-user}.home.packages = [local.chatgpt];

      system.stateVersion = "25.05";
    };
  };
}
