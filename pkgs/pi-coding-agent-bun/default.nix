{
  pi,
  system,
  bun,
  nodejs_24,
}:
pi.packages.${system}.coding-agent-bun.override {
  inherit bun;
  nodejs = nodejs_24;
}
