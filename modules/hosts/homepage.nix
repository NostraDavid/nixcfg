{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.homepage = mkHost {
    hostname = "homepage";
    module = {main-user, ...}: {
      imports = with config.flake.modules.nixos; [
        ../../servers/homepage/hardware-configuration.nix
        proxmox-guest
        homepage
      ];

      networking.hostName = "homepage";
      users.users.${main-user} = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpqILWYPLnnke+4O3dAj61p8p+RghxZhTuP32TP6l07 david@nixos"
        ];
      };
      system.stateVersion = "25.11";
    };
  };
}
