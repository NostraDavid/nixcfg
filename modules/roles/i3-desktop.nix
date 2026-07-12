{config, ...}: {
  flake.modules.nixos.i3-desktop = {
    imports = with config.flake.modules.nixos; [
      desktop-base
      development-core
      dotfiles
      i3
      keyboard
      terminal-core
    ];
  };
}
