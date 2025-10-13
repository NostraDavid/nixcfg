{
  description = "NostraDavid's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixpkgs-unstable,
    home-manager-unstable,
    ...
  } @ inputs: let
    main-user = "david";
    mkHost = {
      hostname,
      path,
    }:
      nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [path];
        specialArgs = {
          inherit inputs;
          hostname = hostname;
          main-user = main-user;
        };
      };
  in {
    nixosConfigurations = {
      wodan = mkHost {
        hostname = "wodan";
        path = ./hosts/wodan/configuration.nix;
      };

      frigg = mkHost {
        hostname = "frigg";
        path = ./hosts/frigg/configuration.nix;
      };
    };
  };
}
