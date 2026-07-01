{
  description = "NostraDavid's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = {nixpkgs, ...} @ inputs: let
    inherit (nixpkgs) lib;
    systems = [
      "x86_64-linux"
    ];
    forAllSystems = f: lib.genAttrs systems f;
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
            pkg = import pkgPath;
            pkgArgs = builtins.functionArgs pkg;
            moldArgs =
              if pkgArgs ? stdenv && !(pkgArgs ? stdenvAdapters)
              then {stdenv = final.moldStdenv;}
              else {};
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
            prev.callPackage pkgPath (moldArgs // fileArgs);
        })
        packageNames);
    overlay-fixes = _final: prev: {
      kdash = prev.kdash.overrideAttrs (old: {
        doCheck = false;
        src = prev.fetchFromGitHub {
          owner = "kdash-rs";
          repo = "kdash";
          rev = "v${old.version}";
          hash = "sha256-CFGZIRZgOUiB/evCDUQFB+w5PJCJNtrWqYzx2yRQKpE=";
        };
      });
    };
    overlay-build-tools = _final: prev: {
      moldStdenv = prev.useMoldLinker prev.stdenv;
    };
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config = {allowUnfree = true;};
        overlays = [overlay-fixes overlay-build-tools overlay-local];
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
            nixpkgs.overlays = [overlay-fixes overlay-build-tools overlay-local];
          }
          ./modules/cachix.nix
          path
        ];
        specialArgs = {
          inherit inputs hostname main-user;
        };
      };
  in {
    overlays.default = overlay-local;

    legacyPackages = forAllSystems pkgsFor;

    # devshell!
    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        # Bootstrap shell for a clean NixOS install: keep this list small and focused
        # on validating/applying the flake before the full user profile is available.
        # Day-to-day editor/language tooling belongs in programs/shared.nix.
        packages = with pkgs; [
          alejandra # Format Nix files before first rebuild
          statix # Catch common Nix antipatterns early
          deadnix # Detect unused Nix bindings while editing the flake
          git # Clone/update this repo and inspect local changes
          just # Run the repo's bootstrap/check/rebuild recipes
        ];

        shellHook = ''
          export NIX_CONFIG="experimental-features = nix-command flakes
          ''${NIX_CONFIG:-}"
        '';
      };
    });

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

      homepage = mkHost {
        hostname = "homepage";
        path = ./servers/homepage/configuration.nix;
      };

      apps = mkHost {
        hostname = "apps";
        path = ./servers/apps/configuration.nix;
      };
    };
  };
}
