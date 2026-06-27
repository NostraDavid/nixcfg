{
  inputs,
  system,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in {
  inherit (unstable) rustPlatform;
}
