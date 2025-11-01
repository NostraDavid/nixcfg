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
    lib = nixpkgs.lib;
    systems = [
      "x86_64-linux"
    ];
    forAllSystems = f: lib.genAttrs systems (system: f system);
    overlay-local = final: prev: {
      nanocoder = prev.callPackage ./pkgs/nanocoder {};
      github-copilot-cli = prev.callPackage ./pkgs/github-copilot-cli {};
      pixieditor = prev.callPackage ./pkgs/pixieditor {};
      bitnet = prev.callPackage ./pkgs/bitnet {};
    };
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config = {allowUnfree = true;};
        overlays = [overlay-local];
      };
    main-user = "david";
    mkHost = {
      hostname,
      path,
    }:
      lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          {
            nixpkgs.overlays = [overlay-local];
          }
          path
        ];
        specialArgs = {
          inherit inputs;
          hostname = hostname;
          main-user = main-user;
        };
      };
  in {
    overlays.default = overlay-local;

    legacyPackages = forAllSystems pkgsFor;

    packages = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      inherit (pkgs) nanocoder github-copilot-cli pixieditor bitnet;
    });

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
