{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.frigg = mkHost {
    hostname = "frigg";
    module = {
      lib,
      main-user,
      pkgs,
      ...
    }: {
      imports = with config.flake.modules.nixos; [
        ../../hosts/frigg/hardware-configuration.nix
        workstation
        laptop
      ];

      nix.settings = {
        cores = lib.mkForce 4;
        max-jobs = lib.mkForce 2;
      };
      systemd.services.nix-daemon.serviceConfig.CPUQuota = "400%";

      home-manager.users.${main-user}.xdg.desktopEntries.chatgpt = {
        name = "ChatGPT";
        genericName = "AI Assistant";
        comment = "Open ChatGPT in app mode";
        exec = "${lib.getExe pkgs.chromium} --class=ChatGPT --app=https://chatgpt.com/";
        icon = "chatgpt";
        terminal = false;
        categories = ["Network" "Utility"];
        startupNotify = true;
        settings.StartupWMClass = "ChatGPT";
      };

      system.stateVersion = "25.05";
    };
  };
}
