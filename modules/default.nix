{inputs, ...}: {
  imports = [
    inputs.flake-parts.flakeModules.modules
    ./features
    ./flake.nix
    ./forgejo-image.nix
    ./hosts
    ./roles
    ./proxmox-lab.nix
  ];
}
