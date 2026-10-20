{
  den,
  inputs,
  constructors,
}: let
  inherit (inputs.nixpkgs) lib;
  nixosNames = [
    "browsers"
    "communication"
    "containers"
    "desktop"
    "desktop-apps"
    "desktop-base"
    "development"
    "development-core"
    "development-lab"
    "dotfiles"
    "full-workstation"
    "gamedev-forge"
    "gaming"
    "homepage"
    "hyprland"
    "i3"
    "i3-workstation"
    "kde-workstation"
    "keyboard"
    "laptop"
    "media"
    "media-production"
    "niri"
    "nvidia-workstation"
    "plasma"
    "proxmox-guest"
    "proxmox-lab-host"
    "selfhosted-apps"
    "terminal"
    "terminal-core"
    "whatpulse"
    "wodan-home"
    "work-communication"
    "workstation-base"
  ];
  homeNames = [
    "browsers"
    "cloud"
    "communication"
    "containers"
    "desktop-apps"
    "development"
    "development-core"
    "development-lab"
    "development-mantle"
    "dotfiles"
    "full-workstation"
    "gamedev-forge"
    "gaming"
    "i3"
    "keyboard"
    "media"
    "media-production"
    "mediaTools"
    "niri"
    "plasma"
    "portable-cli"
    "terminal"
    "terminal-core"
    "whatpulse"
    "wodan"
    "work-communication"
    "workstation"
  ];
  desktopRoles = [
    "desktop"
    "desktop-base"
    "full-workstation"
    "i3-workstation"
    "kde-workstation"
    "workstation-base"
  ];
  aspect = name:
    den.aspects.${
      if name == "wodan-home"
      then "wodan"
      else if name == "portable-cli"
      then "portable-home"
      else name
    };
  publicAspect = name: class:
    if name == "development-lab" && class == "nixos"
    then {
      includes = with den.aspects; [
        development-lab
        gamedev-forge
      ];
    }
    else aspect name;
  resolve = name: class: den.lib.aspects.resolveImports class (publicAspect name class);
  nixosModule = name: let
    # Historical NixOS exports also select their corresponding user feature.
    home = den.lib.aspects.resolveImports "homeManager" (publicAspect name "nixos");
  in
    if home.imports == [] && !(builtins.elem name desktopRoles)
    then resolve name "nixos"
    else
      {main-user, ...}: {
        imports =
          [
            (resolve name "nixos")
          ]
          ++ lib.optional (builtins.elem name desktopRoles) constructors.homeManagerBootstrap;
        config = lib.mkIf (home.imports != []) {
          home-manager.users.${main-user}.imports = [
            home
          ];
        };
      };
in {
  nixos = lib.genAttrs nixosNames nixosModule;
  homeManager = lib.genAttrs homeNames (name: resolve name "homeManager");
}
