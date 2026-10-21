{
  root ? ../.,
  flake ? builtins.getFlake (toString root),
}: let
  inherit (flake.inputs.nixpkgs) lib;
  structural = import ../policy {
    inherit lib;
    inherit (flake.lib) den;
    root = flake.outPath;
  };
  homes =
    builtins.attrValues (lib.mapAttrs (_: home: home.config) flake.homeConfigurations)
    ++ lib.concatMap (system: builtins.attrValues (system.config.home-manager.users or {}))
    (builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations);
  configs = map (system: system.config) (builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations) ++ homes;
  homeSentinel = selected: config:
    (import ../policy/native.nix {
      inherit lib selected config;
      root = flake.outPath;
      graph = [];
      options = {};
      class = "homeManager";
    }).assertion;
  coverage =
    map (homeSentinel ["annotation" "mcp"]) homes
    ++ map (name: homeSentinel ["codex-browser"] flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "frigg" "bragi"];
  coverageFailures = builtins.filter (entry: !entry.assertion) coverage;
  failures = lib.concatMap (config: builtins.filter (entry: !entry.assertion) config.assertions) configs;
in {
  certificateTrust = let
    blacklist = [
      "Comodo AAA Services root"
      "emSign ECC Root CA - G3"
    ];
    systems = builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations;
    standaloneHomes = builtins.filter (home: home.config.targets.genericLinux.enable) (builtins.attrValues flake.homeConfigurations);
  in
    assert lib.all (system: lib.all (name: builtins.elem name system.config.security.pki.caCertificateBlacklist) blacklist) systems;
    assert lib.all (system: system.config.security.pki.installCACerts) (builtins.attrValues flake.darwinConfigurations);
    assert lib.all (system: system.config.environment.variables.SSL_CERT_FILE == "/etc/ssl/certs/ca-certificates.crt") (builtins.attrValues flake.darwinConfigurations);
    assert lib.all (home: let
      bundle = "${home.pkgs.cacert.override {inherit blacklist;}}/etc/ssl/certs/ca-bundle.crt";
    in
      home.config.home.sessionVariables.SSL_CERT_FILE
      == bundle
      && home.config.home.sessionVariables.NIX_SSL_CERT_FILE == bundle)
    standaloneHomes; true;
  structure =
    if structural.valid
    then true
    else throw structural.assertion.message;
  coverage =
    if coverageFailures == []
    then true
    else throw (lib.concatMapStringsSep "\n" (entry: entry.message) coverageFailures);
  effective =
    if failures == []
    then true
    else throw (lib.concatMapStringsSep "\n" (entry: entry.message) failures);
}
