{inputs}: let
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
  mdschemaVersion = "0.16.0";
  packageOverrides = pkgs: let
    inherit (pkgs.stdenv.hostPlatform) system;
    source =
      if system == "x86_64-darwin"
      then pkgs
      else unstableFor system;
  in
    {
      acli = import ./acli.nix {
        inherit pkgs;
        candidate = source.acli;
        formula = inputs.acli-formula;
      };
      mdschema = let
        # Intel macOS still needs the stable toolchain to build the unstable recipe.
        package = pkgs.callPackage (inputs.nixpkgs-unstable + "/pkgs/by-name/md/mdschema/package.nix") {
          buildGoModule = pkgs.buildGo127Module;
        };
        upstream =
          if system == "x86_64-darwin"
          then package
          else source.mdschema;
      in
        if pkgs.lib.versionAtLeast upstream.version mdschemaVersion
        then upstream
        else
          package.overrideAttrs (_: old: {
            version = mdschemaVersion;
            src = old.src.override {hash = "sha256-T/Ca1eEB8qjBOh4wcLC7BpbUd7f/36BKTRB9jhzOvWc=";};
            vendorHash = "sha256-oi56+F7ElNxwd1l95KA8Awpk6e+bv83E64pqZJ1Qr2g=";
          });
      inherit (overlay-ca-security pkgs pkgs) uv;
    }
    // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
      bend = source.bend2.overrideAttrs (old: {
        makeWrapperArgs = old.makeWrapperArgs ++ ["--set-default" "BEND_NO_TELEMETRY" "1"];
      });
    };
  mkLocal = pkgs: pkgs.lib.getAttrs (localPackageNames ++ attrNames (packageOverrides pkgs)) pkgs;
  cachePackageNames = system: outputs: let
    inherit (inputs.nixpkgs.lib) optional versionAtLeast;
    upstream =
      if system == "x86_64-darwin"
      then []
      else ["uv"] ++ optional (versionAtLeast (unstableFor system).mdschema.version mdschemaVersion) "mdschema";
  in
    attrNames (builtins.removeAttrs outputs (["acli"] ++ upstream));
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
      localPackageNames)
    // packageOverrides prev;
  overlay-fixes = _final: prev: {
    pythonPackagesExtensions =
      prev.pythonPackagesExtensions
      ++ [
        (_pyFinal: pyPrev: {
          # Add the missing import for nixpkgs' AnyIO cancellation backport.
          fastmcp =
            if pyPrev.fastmcp.version == "3.2.3"
            then
              pyPrev.fastmcp.overridePythonAttrs (old: {
                patches = (old.patches or []) ++ [../pkgs/fastmcp-anyio.patch];
              })
            else pyPrev.fastmcp;
        })
      ];
    kdash = prev.kdash.overrideAttrs (old: {
      doCheck = false;
      src = prev.fetchFromGitHub {
        owner = "kdash-rs";
        repo = "kdash";
        rev = "v${old.version}";
        hash = "sha256-CFGZIRZgOUiB/evCDUQFB+w5PJCJNtrWqYzx2yRQKpE=";
      };
    });

    kdePackages = prev.kdePackages.overrideScope (_kdeFinal: kdePrev: {
      kwin = kdePrev.kwin.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            ../pkgs/kwin-zoom-per-monitor.patch
          ];
      });
      kwin-x11 = kdePrev.kwin-x11.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            ../pkgs/kwin-x11-zoom-per-monitor.patch
          ];
      });
    });
  };
  overlay-build-tools = _final: prev: {
    moldStdenv = prev.useMoldLinker prev.stdenv;
  };
  overlay-ca-security = import ./ca-security.nix {inherit inputs;};
  overlays = [
    overlay-ca-security
    overlay-fixes
    overlay-build-tools
    overlay-local
  ];
  nixpkgsConfig.allowUnfree = true;
  unstableFor = system:
    import inputs.nixpkgs-unstable {
      inherit system;
      config = nixpkgsConfig;
      overlays = [
        overlay-ca-security
        (_final: prev: {
          glances = let
            version = "4.5.9";
            # Backport the switch from python-jose to PyJWT for older nixpkgs pins.
            package =
              if prev.lib.versionOlder prev.glances.version version
              then
                prev.glances.overridePythonAttrs (old: {
                  inherit version;
                  src = prev.fetchFromGitHub {
                    owner = "nicolargo";
                    repo = "glances";
                    tag = "v${version}";
                    hash = "sha256-CvT9GQ29xXTVxC7V2nGmfDhHLsAtF61+XMMLG8cmHww=";
                  };
                  dependencies = builtins.filter (dependency: (dependency.pname or "") != "python-jose") old.dependencies ++ [prev.python3Packages.pyjwt];
                  nativeCheckInputs = (old.nativeCheckInputs or []) ++ [prev.python3Packages.pysmart];
                })
              else prev.glances;
          in
            if package.version == version
            then
              package.overridePythonAttrs (old: {
                patches = (old.patches or []) ++ [../pkgs/glances-test-readiness.patch];
              })
            else package;
          # Structured wrapper arguments must contain one argument per element.
          sbomnix = prev.sbomnix.overrideAttrs (old: {
            makeWrapperArgs = prev.lib.concatMap (prev.lib.splitString " ") old.makeWrapperArgs;
          });
          pythonPackagesExtensions =
            prev.pythonPackagesExtensions
            ++ [
              (_pyFinal: pyPrev: {
                # sphinxHook reads a space-separated string, not a structured array.
                reuse = pyPrev.reuse.overridePythonAttrs (_old: {
                  sphinxBuilders = "html man";
                });
                # sqliteschema and SimpleSQLite still require typepy < 2.
                typepy = pyPrev.typepy.overridePythonAttrs (_old: {
                  version = "1.3.5";
                  src = prev.fetchFromGitHub {
                    owner = "thombashi";
                    repo = "typepy";
                    tag = "v1.3.5";
                    hash = "sha256-K1XezKOlE4HxSNVM9Y9qAagem3bQlh3K2adzPK4qa/0=";
                  };
                });
              })
            ];
        })
      ];
    };
  pkgsFor = system:
    import inputs.nixpkgs {
      inherit system overlays;
      config = nixpkgsConfig;
    };
in {
  inherit mkLocal cachePackageNames overlays overlay-local overlay-ca-security pkgsFor unstableFor nixpkgsConfig;
}
