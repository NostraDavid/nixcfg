_: let
  # eMudhra intermediate-key compromise, October 2026.
  blacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];
  pki.security.pki.caCertificateBlacklist = blacklist;
in {
  den.aspects.internal-pki = {
    nixos.imports = [
      pki
      {
        security.pki.certificateFiles = [
          ../../certs/freeipa.crt
          ../../certs/forgejo-ca.crt
        ];
      }
    ];
    darwin = {
      imports = [pki];
      environment.variables.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
    homeManager = {
      config,
      lib,
      pkgs,
      ...
    }: let
      bundle = "${pkgs.cacert.override {inherit blacklist;}}/etc/ssl/certs/ca-bundle.crt";
    in {
      home.sessionVariables = lib.mkIf config.targets.genericLinux.enable {
        SSL_CERT_FILE = bundle;
        NIX_SSL_CERT_FILE = bundle;
      };
    };
  };
}
