{inputs, ...}: let
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
    pkgsDir = ../pkgs;
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
  overlays = [overlay-fixes overlay-build-tools overlay-local];
  pkgsFor = system:
    import inputs.nixpkgs {
      inherit system overlays;
      config.allowUnfree = true;
    };
  main-user = "david";
  mkHost = {
    hostname,
    module,
    repoSubdir ? "dev/NostraDavid/nixcfg/trunk",
  }: let
    repoRoot = "/home/${main-user}/${repoSubdir}";
  in
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {nixpkgs.overlays = overlays;}
        ./cachix.nix
        module
      ];
      specialArgs = {
        inherit inputs hostname main-user repoRoot;
      };
    };
in {
  systems = ["x86_64-linux"];

  _module.args = {inherit mkHost;};

  flake.overlays.default = overlay-local;

  perSystem = {system, ...}: let
    pkgs = pkgsFor system;
    stable = pkgs;
    inherit (builtins) attrNames filter listToAttrs map readDir;
    entries = readDir ../pkgs;
    localPackageNames =
      filter (name: entries.${name} == "directory") (attrNames entries);
  in {
    _module.args.pkgs = pkgs;

    legacyPackages = pkgs;

    packages =
      listToAttrs (map
        (name: {
          inherit name;
          value = pkgs.${name};
        })
        localPackageNames)
      // {
        win11-icon-theme =
          pkgs.win11-icon-theme or (pkgs.callPackage (builtins.path {
            path = ../pkgs/win11-icon-theme;
            name = "win11-icon-theme";
          }) {});
        win11os-kde =
          pkgs.win11os-kde or (pkgs.callPackage (builtins.path {
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
