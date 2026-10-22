{den, ...}: {
  den.aspects.nixos-base = {
    includes = with den.aspects; [
      cachix
      fonts
      internal-pki
    ];
    nixos = {pkgs, ...}: {
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
