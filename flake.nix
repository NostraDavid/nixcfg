{
  description = "NostraDavid's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    main-user = "david";
  in {
    nixosConfigurations = {
      wodan = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [./hosts/wodan/configuration.nix];
        specialArgs = {
          inherit inputs;
          hostname = "wodan";
          main-user = main-user;
        };
      };

      frigg = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/frigg/configuration.nix
        ];
        specialArgs = {
          inherit inputs;
          hostname = "frigg";
          main-user = main-user;
        };
      };
    };
  };
}
