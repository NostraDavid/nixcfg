{config, ...}: {
  flake.modules.nixos.i3-workstation = {
    imports = with config.flake.modules.nixos; [
      workstation-base
      i3
    ];
  };
}
