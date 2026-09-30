{inputs, ...}: {
  imports = [
    inputs.flake-parts.flakeModules.modules
    ./features
    ./flake.nix
    ./forgejo-image.nix
    ./proxy-image.nix
    ./hosts
    ./workstation.nix
    ./roles
    ./proxmox-lab.nix
  ];
}
