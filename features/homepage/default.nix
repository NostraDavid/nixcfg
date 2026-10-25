_: {
  den.aspects.homepage.nixos = {pkgs, ...}: {
    services.homepage-dashboard = {
      enable = true;
      listenPort = 3000;
      allowedHosts = "home.powerlan.empire,localhost:3000,127.0.0.1:3000";
      settings.title = "PowerLAN";
    };
    # Node must use the host's filtered public roots and internal CA certificates.
    systemd.services.homepage-dashboard.environment = {
      HOSTNAME = "0.0.0.0";
      NODE_OPTIONS = "--use-openssl-ca";
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      SSL_CERT_DIR = "${pkgs.emptyDirectory}";
    };
    security.pki.certificateFiles = [../../hosts/physical/wodan/certs/proxmox.crt];
  };
}
