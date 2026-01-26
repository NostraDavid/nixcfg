{
  description = "NostraDavid's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
    overlay-local = final: prev: let
      inherit
        (builtins)
        attrNames
        filter
        listToAttrs
        map
        pathExists
        readDir
        ;
      pkgsDir = ./pkgs;
      entries = readDir pkgsDir;
      packageNames =
        filter (name: entries.${name} == "directory") (attrNames entries);
    in
      listToAttrs (map
        (name: {
          inherit name;
          value = let
            pkgPath = pkgsDir + "/${name}";
            argsPath = pkgPath + "/args.nix";
            fileArgs =
              if pathExists argsPath
              then
                import argsPath {
                  inherit final prev inputs;
                  system = final.stdenv.system;
                }
              else {};
          in
            prev.callPackage pkgPath fileArgs;
        })
        packageNames);
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
      inherit (builtins) attrNames filter listToAttrs map readDir;
      pkgs = pkgsFor system;
      entries = readDir ./pkgs;
      localPackageNames =
        filter (name: entries.${name} == "directory") (attrNames entries);
    in
      listToAttrs (map
        (name: {
          inherit name;
          value = pkgs.${name};
        })
        localPackageNames));

    nixosConfigurations = {
      wodan = mkHost {
        hostname = "wodan";
        path = ./hosts/wodan/configuration.nix;
      };

      frigg = mkHost {
        hostname = "frigg";
        path = ./hosts/frigg/configuration.nix;
      };

      bragi = mkHost {
        hostname = "bragi";
        path = ./hosts/bragi/configuration.nix;
      };
    };
  };
}
