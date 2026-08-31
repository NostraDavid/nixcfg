{config, ...}: {
  flake.modules = {
    nixos.full-workstation = {main-user, ...}: {
      imports = with config.flake.modules.nixos; [
        kde-workstation
        work-communication
        development-lab
        gaming
        media-production
        whatpulse
      ];

      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.full-workstation
      ];
    };

    homeManager.full-workstation = {
      local,
      stable,
      ...
    }: {
      imports = [../home/full-workstation-taskbar.nix];

      home.packages = [
        local.chatgpt # Official ChatGPT desktop application
        stable.libreoffice-qt6 # Full office suite for primary workstations
        stable.wireguard-ui # Graphical WireGuard administration
      ];
    };
  };
}
