{
  den,
  constructors,
  inputs,
  ...
}: {
  den.hosts.x86_64-linux.frigg = {
    aspect = den.aspects.host-frigg;
    instantiate = constructors.nixos {
      hostname = "frigg";
      homeManager = true;
    };
    users.david = {
      classes = [
        "homeManager"
      ];
      aspect.includes = [
        den.batteries.host-aspects
      ];
    };
  };

  den.aspects.host-frigg = {
    includes = with den.aspects; [
      codex-browser
      kde-workstation
      laptop
    ];
    nixos = {
      inputs,
      lib,
      ...
    }: {
      imports = [
        ./hardware-configuration.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen1
      ];

      nix.settings = {
        cores = lib.mkForce 4;
        max-jobs = lib.mkForce 2;
      };
      systemd.services.nix-daemon.serviceConfig.CPUQuota = "400%";

      networking.hostName = "frigg";

      system.stateVersion = "25.05";
      fileSystems."/media/usb" = {
        device = "/dev/disk/by-uuid/a0ff5645-3695-4a32-9917-51d98d453d21";
        fsType = "vfat";
        options = [
          "nofail"
          "x-systemd.automount"
        ];
      };
    };
    homeManager = {local, ...}: {
      imports = [
        # These integrations declare options; host features select their settings.
        inputs.plasma-manager.homeModules.plasma-manager
        inputs.codex-desktop-linux.homeManagerModules.default
      ];
      programs.home-manager.enable = true;
      home = {
        username = "david";
        homeDirectory = "/home/david";
        stateVersion = "25.05";
        packages = [
          local.chatgpt
          local.t3code
        ];
      };
    };
  };
}
