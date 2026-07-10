{
  flake.modules.nixos.proxmox-guest = {
    imports = [
      ../proxmox-vm.nix
      ../server-locale.nix
      ../server-nix.nix
    ];
  };
}
