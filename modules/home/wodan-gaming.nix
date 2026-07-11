{
  inputs,
  pkgs,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
in {
  home.packages = with pkgs; [
    itch
    # games
    # unstable.openra_2019-release
    endless-sky
    godot
    unstable.openrct2
  ];
}
