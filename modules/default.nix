{inputs, ...}: {
  imports = [
    inputs.flake-parts.flakeModules.modules
    ./features
    ./flake.nix
    ./hosts
    ./roles
  ];
}
