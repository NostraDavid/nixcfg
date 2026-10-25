{
  pkgs,
  unstable,
  flake,
}: let
  builders = import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    overlays = [(import ../nix/brotli-security.nix)];
  };
  upstream = import unstable.path {
    system = unstable.stdenv.hostPlatform.system;
    overlays = [];
  };
  profile = pkgs.buildEnv {
    name = "ca-python-profile";
    paths = [(pkgs.lib.hiPrio pkgs.python3Ca) (pkgs.python3.withPackages (_: []))];
  };
  chains = pkgs.fetchurl {
    url = "https://emudhra.we-have-a-problem.com/chains.zip";
    hash = "sha256-e5SZVpVfxQGjD02Y0vUT00wLu+kuKaloGUyW4JfOI0U=";
  };
  oldCertifi = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/12/90/3c9ff0512038035f59d279fddeb79f5f1eccd8859f06d6163c58798b9487/certifi-2024.8.30-py3-none-any.whl";
    hash = "sha256-kiggtT23pyV/+9o/WXJm1DUkWQPYBzfjT4pF/z4yMNg=";
  };
in
  assert pkgs.python3.drvPath == builders.python3.drvPath;
  assert pkgs.rustc.drvPath == builders.rustc.drvPath;
  assert pkgs.lib.versionAtLeast upstream.cacert.version "3.131.1" -> unstable.cacert.drvPath == upstream.cacert.drvPath;
    pkgs.runCommand "certificate-trust-check" {
      nativeBuildInputs = [pkgs.python3Ca pkgs.openssl];
      CA_REPAIR_SCRIPT = ../scripts/repair-python-ca.py;
      CA_OLD_CERTIFI = oldCertifi;
      CA_CHAINS = chains;
      CA_PRIVATE_ROOT = ../certs/freeipa.crt;
      CA_NODE_PACKAGE = pkgs.nodejs_24;
      CA_BUNDLES = builtins.concatStringsSep " " [
        "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "${unstable.cacert}/etc/ssl/certs/ca-bundle.crt"
        (toString flake.nixosConfigurations.wodan.config.environment.etc."ssl/certs/ca-certificates.crt".source)
        flake.homeConfigurations.mimir2.config.home.sessionVariables.SSL_CERT_FILE
      ];
      CA_PIP_PACKAGES = builtins.concatStringsSep " " [
        (toString pkgs.python3Packages.pip)
        (toString unstable.python3Packages.pip)
      ];
    } ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${profile}/bin/python3 -m venv "$TMPDIR/venv"
      ${pkgs.python3Packages.virtualenv}/bin/virtualenv --no-download --no-periodic-update "$TMPDIR/virtualenv"
      export CA_SEEDED_PIP="$TMPDIR/venv $TMPDIR/virtualenv"
      python3 ${./test-ca-trust.py}
      openssl verify -no-CApath -no-CAstore \
        -CAfile ${flake.nixosConfigurations.wodan.config.environment.etc."ssl/certs/ca-certificates.crt".source} \
        ${../certs/freeipa.crt} ${../certs/forgejo-ca.crt}
      touch "$out"
    ''
