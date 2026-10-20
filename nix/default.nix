{
  inputs,
  self,
  ...
}: let
  packageSets = import ./packages.nix {inherit inputs;};
  evaluate = import ./evaluate.nix {inherit inputs packageSets self;};
  fleet = evaluate {};
  constructors = import ./constructors.nix {
    inherit inputs packageSets;
    inherit (fleet) den;
  };
  mkMimir2 = {extraHomeModules ? []}:
    (evaluate {
      inventory = [../inventory/mimir2.nix];
      mimir2Spec = {inherit extraHomeModules;};
    }).flake.homeConfigurations."david@mimir2";
  mkLoki = {
    extraDarwinModules ? [],
    extraHomeModules ? [],
    username ? "david",
    homeDirectory ? "/Users/${username}",
    hostname ? "loki",
  }:
    (evaluate {
      inventory = [../inventory/loki.nix];
      lokiSpec = {inherit extraDarwinModules extraHomeModules username homeDirectory hostname;};
    }).flake.darwinConfigurations.loki;
in {
  imports = [
    inputs.flake-parts.flakeModules.modules
    ./outputs.nix
    ./forgejo-image.nix
    ./proxy-image.nix
    ./proxmox-lab.nix
  ];
  flake = {
    inherit (fleet.flake) nixosConfigurations darwinConfigurations homeConfigurations;
    modules = import ./public.nix {
      inherit inputs constructors;
      inherit (fleet) den;
    };
    lib = {
      inherit mkMimir2 mkLoki;
      inherit (packageSets) unstableFor;
      inherit (fleet) den;
    };
  };
}
