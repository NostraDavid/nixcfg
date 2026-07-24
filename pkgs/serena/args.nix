{
  inputs,
  system,
  ...
}: {
  serena = inputs.serena.packages.${system}.default;
}
