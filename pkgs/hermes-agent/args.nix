{
  inputs,
  system,
  ...
}: {
  hermes-agent = inputs.hermes-agent.packages.${system}.default;
}
