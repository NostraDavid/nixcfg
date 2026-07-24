{
  inputs,
  system,
  ...
}: {
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
}
