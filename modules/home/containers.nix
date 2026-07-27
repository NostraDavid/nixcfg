{
  inputs,
  pkgs,
  ...
}: let
  stable = pkgs;
  unstable = import inputs.nixpkgs-unstable {
    inherit (stable.stdenv.hostPlatform) system;
    config = stable.config // {allowUnfree = true;};
  };
in {
  home.packages = [
    stable.dockerfile-roast # Opinionated Dockerfile linter
    # podman
    unstable.podman-desktop # GUI for managing containers
    unstable.podman-compose # docker-compose alternative
  ];
}
