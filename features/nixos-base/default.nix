{den, ...}: {
  den.aspects.nixos-base = {
    includes = with den.aspects; [
      cachix
      internal-pki
    ];
    nixos = {pkgs, ...}: {
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
