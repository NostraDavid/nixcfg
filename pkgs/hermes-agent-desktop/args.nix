{
  inputs,
  system,
  ...
}: {
  hermesAgentDesktop = inputs.hermes-agent.packages.${system}.desktop;
  hermesAgentSrc = inputs.hermes-agent.outPath;
}
