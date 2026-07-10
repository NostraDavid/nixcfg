{mkHost, ...}: let
  configuration = {
    hostname,
    main-user,
    ...
  }: {
    imports = [
      ../../servers/apps/hardware-configuration.nix
      ../proxmox-vm.nix
      ../server-locale.nix
      ../server-nix.nix
      ../selfhosted-apps.nix
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
  flake.nixosConfigurations.apps = mkHost {
    hostname = "apps";
    module = configuration;
  };
}
