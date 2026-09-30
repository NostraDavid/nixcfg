{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.sbomnix # Software Bill of Materials generator
    unstable.grype # Vulnerability scanner
    unstable.osv-scanner # Open Source Vulnerability Scanner
    unstable.syft # SBOM generator
    unstable.vulnix # Nix vulnerability scanner
  ];
}
