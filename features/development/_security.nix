{unstable, ...}: {
  home.packages = [
    unstable.grype # Scan artifacts and container images for vulnerabilities
    unstable.osv-detector # Detect vulnerable open-source dependencies
    unstable.osv-scanner # Scan projects and lockfiles against OSV
    unstable.sbomnix # Generate SBOMs for Nix closures
    unstable.syft # Generate and convert software bills of materials
    unstable.vulnix # Scan Nix closures for known vulnerabilities
  ];
}
