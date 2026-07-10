{mkHost, ...}: let
  configuration = {
    hostname,
    main-user,
    ...
  }: {
    imports = [
      ../../servers/homepage/hardware-configuration.nix
      ../proxmox-vm.nix
      ../server-locale.nix
      ../server-nix.nix
      ../homepage-container.nix
    ];

    networking.hostName = hostname;

    users.users.${main-user} = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpqILWYPLnnke+4O3dAj61p8p+RghxZhTuP32TP6l07 david@nixos"
      ];
    };

    system.stateVersion = "25.11";
  };
in {
  flake.nixosConfigurations.homepage = mkHost {
    hostname = "homepage";
    module = configuration;
  };
}
