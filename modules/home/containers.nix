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
    # podman
    unstable.podman-desktop # GUI for managing containers
    unstable.podman-compose # docker-compose alternative
  ];
}
