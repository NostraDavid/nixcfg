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
      repoRoot,
      unstable,
      ...
    }: let
      bundle =
        if config.targets.genericLinux.enable
        then "${pkgs.cacert.override {blacklist = blacklist pkgs;}}/etc/ssl/certs/ca-bundle.crt"
        else "/etc/ssl/certs/ca-certificates.crt";
    in {
      home = {
        packages = [(lib.hiPrio pkgs.python3Ca)];
        sessionVariables = variables pkgs bundle;
        file = {
          ".local/bin/python" = {
            source = "${pkgs.python3Ca}/bin/python";
            force = true;
          };
          ".local/bin/python3" = {
            source = "${pkgs.python3Ca}/bin/python3";
            force = true;
          };
          ".local/bin/uv" = {
            source = lib.getExe unstable.uv;
            force = true;
          };
          ".local/bin/uvx" = {
            source = "${unstable.uv}/bin/uvx";
            force = true;
          };
        };
        activation.repairPythonTrust = lib.hm.dag.entryAfter ["writeBoundary"] ''
          for directory in "$(${lib.getExe unstable.uv} python dir)" "$(${lib.getExe unstable.uv} tool dir)" ${lib.escapeShellArg "${repoRoot}/.venv"}; do
            if [ -d "$directory" ]; then
              run ${pkgs.python3}/bin/python3 ${../../scripts/repair-python-ca.py} --apply "$directory"
            fi
          done
        '';
      };
    };
  };
}
