{stable, ...}: {
  home.packages = [
    stable.grype # Scan artifacts and container images for vulnerabilities
    stable.osv-detector # Detect vulnerable open-source dependencies
    stable.osv-scanner # Scan projects and lockfiles against OSV
    stable.sbomnix # Generate SBOMs for Nix closures
    stable.syft # Generate and convert software bills of materials
    stable.vulnix # Scan Nix closures for known vulnerabilities
  ];
}
