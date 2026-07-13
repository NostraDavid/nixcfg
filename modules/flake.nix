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
    repoSubdir ? "nixcfg",
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
    inherit (builtins) attrNames filter listToAttrs map readDir;
    entries = readDir ../pkgs;
    localPackageNames =
      filter (name: entries.${name} == "directory") (attrNames entries);
  in {
    _module.args.pkgs = pkgs;

    legacyPackages = pkgs;

    packages = listToAttrs (map
      (name: {
        inherit name;
        value = pkgs.${name};
      })
      localPackageNames);

    devShells.default = pkgs.mkShell {
      # Bootstrap shell for a clean NixOS install: keep this list small and focused
      # on validating/applying the flake before the full user profile is available.
      # Day-to-day tooling is grouped by capability under modules/home/.
      packages = with pkgs; [
        alejandra # Format Nix files before first rebuild
        statix # Catch common Nix antipatterns early
        deadnix # Detect unused Nix bindings while editing the flake
        git # Clone/update this repo and inspect local changes
        git-lfs # Run the globally managed LFS hooks
        just # Run the repo's bootstrap/check/rebuild recipes
        prek # Run project hooks from the global dispatcher
        ruff
        shellcheck
        markdownlint-cli
        stylua
        selene
        oxfmt
        shfmt
        uv # Run the globally managed scoped commit-message hook
        opentofu
        vulnix
        sbomnix
        osv-scanner
        grype
      ];

      shellHook = ''
        export NIX_CONFIG="experimental-features = nix-command flakes
        ''${NIX_CONFIG:-}"
      '';
    };
  };
}
