{den, ...}: {
  den.aspects.nixos-base = {
    includes = with den.aspects; [
      cachix
      fonts
      internal-pki
    ];
    nixos = {pkgs, ...}: {
      environment.etc."xdg/plasma_workspace.notifyrc".text = ''
        [Event/notification]
        Action=Popup|Sound
        Sound=message
      '';
      programs.git = {
        enable = true;
        lfs.enable = true;
      };
      environment.systemPackages = [
        pkgs.cmux-tui
        pkgs.iperf3
        pkgs.mc
        pkgs.opencode-v2
        pkgs.tree
      ];
    };
  };
}
