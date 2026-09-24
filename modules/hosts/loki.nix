{mkLoki, ...}: {
  flake.darwinConfigurations.loki = mkLoki {};
}
