{
  hostname,
  main-user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/proxmox-vm.nix
    ../../modules/server-locale.nix
    ../../modules/server-nix.nix
    ../../modules/homepage-container.nix
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
}
