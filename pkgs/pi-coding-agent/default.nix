{
  pi,
  system,
  typescript,
}:
pi.packages.${system}.coding-agent.override {
  inherit typescript;
}
