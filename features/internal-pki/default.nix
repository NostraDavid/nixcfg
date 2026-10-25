_: let
  # eMudhra intermediate-key compromise, October 2026.
  blacklist = pkgs: import ../../nix/ca-blacklist.nix pkgs.cacert.version;
  variables = pkgs: bundle: {
    SSL_CERT_FILE = bundle;
    SSL_CERT_DIR = "${pkgs.emptyDirectory}";
    NIX_SSL_CERT_FILE = bundle;
    REQUESTS_CA_BUNDLE = bundle;
    CURL_CA_BUNDLE = bundle;
    GIT_SSL_CAINFO = bundle;
    PIP_CERT = bundle;
  };
  pki = {pkgs, ...}: {
    security.pki.caCertificateBlacklist = blacklist pkgs;
    environment.variables = variables pkgs "/etc/ssl/certs/ca-certificates.crt";
  };
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
    darwin = {pkgs, ...}: {
      imports = [pki];
      system.activationScripts.postActivation.text = ''
        # Apple CLI tools also read this separate bundle, including under sudo.
        if [[ ! -v DRY_RUN ]] && [ -f /etc/ssl/cert.pem ]; then
          ${pkgs.python3}/bin/python3 ${../../scripts/repair-python-ca.py} --apply /etc/ssl/cert.pem
        fi
      '';
    };
    homeManager = {
      config,
      lib,
      pkgs,
      local,
      repoRoot,
      ...
    }: let
      bundle =
        if config.targets.genericLinux.enable
        then "${pkgs.cacert.override {blacklist = blacklist pkgs;}}/etc/ssl/certs/ca-bundle.crt"
        else "/etc/ssl/certs/ca-certificates.crt";
    in {
      home = {
        sessionVariables = variables pkgs bundle;
        file = {
          ".local/bin/uv" = {
            source = lib.getExe local.uv;
            force = true;
          };
          ".local/bin/uvx" = {
            source = "${local.uv}/bin/uvx";
            force = true;
          };
        };
        activation.repairPythonTrust = lib.hm.dag.entryAfter ["writeBoundary"] ''
          for directory in "$(${lib.getExe local.uv} python dir)" "$(${lib.getExe local.uv} tool dir)" ${lib.escapeShellArg "${repoRoot}/.venv"}; do
            if [ -d "$directory" ]; then
              run ${pkgs.python3}/bin/python3 ${../../scripts/repair-python-ca.py} --apply "$directory"
            fi
          done
        '';
      };
    };
  };
}
