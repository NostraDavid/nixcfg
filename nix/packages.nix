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
  overlay-ca-security = import ./ca-security.nix;
  overlay-brotli-security = import ./brotli-security.nix;
  overlays = [
    overlay-ca-security
    overlay-brotli-security
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
        overlay-brotli-security
        (_final: prev: {
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
  brotliReplacements = packageSets:
    inputs.nixpkgs.lib.unique (inputs.nixpkgs.lib.concatMap
      (pkgs:
        pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux
        (map (output: {
            oldDependency = pkgs.lib.getOutput output pkgs.brotli;
            newDependency = pkgs.lib.getOutput output pkgs.brotliPatched;
          })
          pkgs.brotli.outputs))
      packageSets);
  checkBrotliRuntime = pkgs: replacements: drv: let
    builders = import pkgs.path {system = pkgs.stdenv.buildPlatform.system;};
    # Always copy the NAR, including self references; never rebuild an unchanged app.
    copy = builders.replaceDirectDependencies {
      inherit drv;
      replacements = [
        {
          oldDependency = drv;
          newDependency = builtins.placeholder "out";
        }
      ];
    };
  in
    copy.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.python3];
      exportReferencesGraph = (old.exportReferencesGraph or []) ++ ["brotli-runtime" drv];
      disallowedRequisites = (old.disallowedRequisites or []) ++ map (r: r.oldDependency) replacements;
      buildCommand =
        old.buildCommand
        + "\n"
        + ''
          while read -r dependency; do
            library="$dependency/lib/libbrotlidec.so"
            if [ -f "$library" ]; then
              BROTLI_LIBRARY="$library" BROTLI_CLI=${pkgs.lib.getExe pkgs.brotliPatched} \
                ${pkgs.python3}/bin/python3 ${../checks/test-brotli-security.py}
            fi
          done < brotli-runtime
        '';
    });
  graftBrotliRuntime = pkgs: packageSets: drv: let
    # NAR rewriting needs no locally modified Nix or its build toolchain.
    builders = import pkgs.path {system = pkgs.stdenv.buildPlatform.system;};
    replacements = brotliReplacements packageSets;
  in
    checkBrotliRuntime pkgs replacements (builders.replaceDependencies {
      inherit drv replacements;
      verbose = false;
    });
in {
  inherit mkLocal overlays overlay-local overlay-ca-security overlay-brotli-security pkgsFor unstableFor nixpkgsConfig brotliReplacements checkBrotliRuntime graftBrotliRuntime;
}
