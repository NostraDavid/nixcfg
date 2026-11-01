{pkgs, ...}: let
  feed = pkgs.writeShellApplication {
    name = "homepage-nitter-feed";
    runtimeInputs = [pkgs.python3];
    text = ''exec python3 ${../../scripts/homepage-nitter-feed.py}'';
  };
in {
  systemd.services.homepage-nitter-feed = {
    description = "Cache the public thsottiaux Nitter RSS feed for Homepage";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    serviceConfig = {
      ExecStart = "${feed}/bin/homepage-nitter-feed";
      DynamicUser = true;
      StateDirectory = "homepage-nitter-feed";
      StateDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = "10s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
      UMask = "0077";
    };
  };
}
