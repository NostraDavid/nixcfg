{unstable, ...}: {
  home.packages = [
    unstable.grype # Vulnerability scanner
    unstable.osv-scanner # Open Source Vulnerability Scanner
    unstable.sbomnix # Software Bill of Materials generator
    unstable.syft # SBOM generator
    unstable.vulnix # Nix vulnerability scanner
  ];
}
