{
  root,
  den ? null,
  class,
  selected ? [],
  required ? [],
  expectedHome ? null,
}: {
  lib,
  config,
  options,
  extendModules,
  ...
}: let
  result = import ./native.nix {
    inherit lib root den class selected required expectedHome config options;
    inherit (extendModules {}) graph;
  };
in {
  assertions = [
    result.assertion
  ];
}
