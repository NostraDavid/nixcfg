{
  pi,
  system,
  nodejs_24,
}:
pi.packages.${system}.coding-agent.override {
  nodejs = nodejs_24;
}
