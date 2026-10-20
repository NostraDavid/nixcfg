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
      hostModules = [
        ../hosts/physical/mimir2/default.nix
      ];
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
      hostModules = [
        ../hosts/physical/loki/default.nix
      ];
      lokiSpec = {inherit extraDarwinModules extraHomeModules username homeDirectory hostname;};
    }).flake.darwinConfigurations.loki;
in {
  imports = [
    ./forgejo-image.nix
    ./outputs.nix
    ./proxmox-lab.nix
    ./proxy-image.nix
    inputs.flake-parts.flakeModules.modules
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
