{den, ...}: {
  den.aspects.proxmox-guest = {
    includes = with den.aspects; [proxmox-vm server-locale server-nix];
  };
}
