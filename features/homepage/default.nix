_: {
  den.aspects.homepage = {
    nixos.imports = [
      ({
        config,
        pkgs,
        ...
      }: let
        homepageHosts = "homepage,homepage.local,homepage.home.arpa,192.168.2.101";
      in {
        systemd.tmpfiles.rules = [
          "d /var/lib/homepage 0750 homepage homepage -"
          "d /var/lib/homepage/config 0750 homepage homepage -"
        ];

        users = {
          groups.homepage.gid = 991;
          users.homepage = {
            isSystemUser = true;
            group = "homepage";
            uid = 991;
          };
        };

        virtualisation = {
          podman.enable = true;
          oci-containers = {
            backend = "podman";
            containers.homepage = {
              image = "ghcr.io/gethomepage/homepage@sha256:c881120b024d6a8e2f3c9664efc568984e4352e47df459d6b32e225374c71955";
              ports = [
                "127.0.0.1:3000:3000"
              ];
              volumes = [
                "/var/lib/homepage/config:/app/config"
                "${config.environment.etc."ssl/certs/ca-certificates.crt".source}:/etc/ssl/certs/ca-certificates.crt:ro"
                "${pkgs.emptyDirectory}:/etc/ssl/nix-empty:ro"
              ];
              environment = {
                HOMEPAGE_ALLOWED_HOSTS = homepageHosts;
                PUID = toString config.users.users.homepage.uid;
                PGID = toString config.users.groups.homepage.gid;
                # The image's independent Node roots predate the CA incident.
                NODE_OPTIONS = "--use-openssl-ca";
                SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
                SSL_CERT_DIR = "/etc/ssl/nix-empty";
              };
            };
          };
        };

        services.nginx = {
          enable = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;
          virtualHosts."homepage.home.arpa" = {
            default = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:3000";
              proxyWebsockets = true;
            };
          };
        };
      })
    ];
  };
}
