{
  hostname,
  main-user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/proxmox-vm.nix
    ../../modules/location.nix
    ../../modules/i18n.nix
    ../../modules/storage_optimization.nix
    ../../modules/selfhosted-apps.nix
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
