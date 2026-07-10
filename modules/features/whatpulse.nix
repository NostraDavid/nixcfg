{
  flake.modules.nixos.whatpulse = {
    pkgs,
    main-user,
    ...
  }: {
    hardware.uinput.enable = true;

    users = {
      groups.uinput = {};
      users.${main-user}.extraGroups = ["uinput"];
    };

    systemd.services.whatpulse-pcap-service = {
      description = "WhatPulse PCap Service";
      documentation = ["https://whatpulse.org/"];
      after = ["network.target"];
      wants = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        ExecStart = "${pkgs."whatpulse-pcap-service"}/bin/whatpulse-pcap-service";
        Restart = "always";
        RestartSec = 5;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        CapabilityBoundingSet = ["CAP_NET_RAW" "CAP_NET_ADMIN"];
        AmbientCapabilities = ["CAP_NET_RAW" "CAP_NET_ADMIN"];
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };
}
