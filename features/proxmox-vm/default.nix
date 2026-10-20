_: {
  den.aspects.proxmox-vm = {
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
