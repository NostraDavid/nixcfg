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
      # Add your SSH public key before deploying.
    ];
  };

  system.stateVersion = "25.11";
}
