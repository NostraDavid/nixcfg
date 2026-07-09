{config, ...}: let
  homepageHosts = "homepage,homepage.local,homepage.home.arpa,192.168.2.101";
in {
  fileSystems."/var/lib/homepage" = {
    device = "/dev/disk/by-label/homepage-data";
    fsType = "ext4";
    options = ["nofail" "x-systemd.device-timeout=10s"];
  };

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
        ports = ["127.0.0.1:3000:3000"];
        volumes = [
          "/var/lib/homepage/config:/app/config"
        ];
        environment = {
          HOMEPAGE_ALLOWED_HOSTS = homepageHosts;
          PUID = toString config.users.users.homepage.uid;
          PGID = toString config.users.groups.homepage.gid;
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
}
