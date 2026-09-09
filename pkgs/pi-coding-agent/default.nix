{
  pi,
  system,
  typescript,
  typescript-go,
}:
pi.packages.${system}.coding-agent.override {
  inherit typescript typescript-go;
}
