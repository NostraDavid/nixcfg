{inputs, ...}: let
  inherit
    (builtins)
    attrNames
    filter
    listToAttrs
    pathExists
    readDir
    ;
  pkgsDir = ../pkgs;
  entries = readDir pkgsDir;
  localPackageNames =
    filter (name: entries.${name} == "directory") (attrNames entries);
  mkLocal = pkgs:
    listToAttrs (map
      (name: {
        inherit name;
        value = pkgs.${name};
      })
      localPackageNames);
  overlay-local = final: prev:
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
                unstable = unstableFor final.stdenv.system;
              }
            else {};
        in
          prev.callPackage pkgPath (moldArgs // fileArgs);
      })
      localPackageNames);
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
  overlay-unstable-fixes = _final: prev: {
    # Textual 8.2.8 can race the parent mount in this upstream test.
    mistral-vibe = prev.mistral-vibe.overrideAttrs (old: {
      disabledTests =
        (old.disabledTests or [])
        ++ ["test_idle_skill_fires_telemetry"];
    });
  };
  overlay-build-tools = _final: prev: {
    moldStdenv = prev.useMoldLinker prev.stdenv;
  };
  overlays = [overlay-fixes overlay-build-tools overlay-local];
  nixpkgsConfig.allowUnfree = true;
  unstableFor = system:
    import inputs.nixpkgs-unstable {
      inherit system;
      overlays = [overlay-unstable-fixes];
      config = nixpkgsConfig;
    };
  pkgsFor = system:
    import inputs.nixpkgs {
      inherit system overlays;
      config = nixpkgsConfig;
    };
  main-user = "david";
  mkHost = {
    hostname,
    module,
    repoSubdir ? "dev/NostraDavid/nixcfg/trunk",
  }: let
    repoRoot = "/home/${main-user}/${repoSubdir}";
    system = "x86_64-linux";
    unstable = unstableFor system;
  in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ({pkgs, ...}: {
          # Keep package-source qualifiers readable without rebuilding or
          # re-aliasing the configured NixOS package set in every module.
          _module.args = {
            stable = pkgs;
            local = mkLocal pkgs;
          };
        })
        {
          nixpkgs = {
            inherit overlays;
            config = nixpkgsConfig;
          };
        }
        ./cachix.nix
        module
      ];
      specialArgs = {
        inherit inputs hostname main-user repoRoot unstable;
      };
    };
in {
  systems = ["x86_64-linux"];

  _module.args = {inherit mkHost;};

  flake.overlays.default = overlay-local;

  perSystem = {system, ...}: let
    stable = pkgsFor system;
  in {
    _module.args.pkgs = stable;

    legacyPackages = stable;

    packages =
      mkLocal stable
      // {
        win11-icon-theme =
          stable.win11-icon-theme or (stable.callPackage (builtins.path {
            path = ../pkgs/win11-icon-theme;
            name = "win11-icon-theme";
          }) {});
        win11os-kde =
          stable.win11os-kde or (stable.callPackage (builtins.path {
            path = ../pkgs/win11os-kde;
            name = "win11os-kde";
          }) {});
      };

    devShells.default = stable.mkShell {
      # Bootstrap shell for a clean NixOS install: keep this list small and focused
      # on validating/applying the flake before the full user profile is available.
      # Day-to-day tooling is grouped by capability under modules/home/.
      packages = [
        stable.bashInteractive # Keep nested shells and terminal profiles Readline-capable
        stable.alejandra # Format Nix files before first rebuild
        stable.statix # Catch common Nix antipatterns early
        stable.deadnix # Detect unused Nix bindings while editing the flake
        stable.git # Clone/update this repo and inspect local changes
        stable.git-lfs # Run the globally managed LFS hooks
        stable.just # Run the repo's bootstrap/check/rebuild recipes
        stable.prek # Run project hooks from the global dispatcher
        stable.ruff
        stable.shellcheck
        stable.markdownlint-cli
        stable.stylua
        stable.selene
        stable.dprint
        stable.shfmt
        stable.uv # Run the globally managed scoped commit-message hook
        stable.opentofu
        stable.vulnix
        stable.sbomnix
        stable.osv-scanner
        stable.grype
      ];

      shellHook = ''
        export SHELL="${stable.bashInteractive}/bin/bash"
        export NIX_CONFIG="experimental-features = nix-command flakes
        ''${NIX_CONFIG:-}"
      '';
    };
  };
}
