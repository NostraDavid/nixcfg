{
  local,
  stable,
  ...
}: {
  home.packages = [
    local.hermes-agent-desktop # Desktop client for the Hermes coding agent
    stable.dotnet-sdk # .NET development kit
    stable.exfatprogs # ExFAT FS utilities
    stable.helm # Kubernetes package manager
    stable.k3d # k3s in docker
    stable.k3s # kubes (includes kubectl)
    stable.postgresql # for psql; there's pgcli for shared
    stable.redpanda-client # Kafka alternative
    stable.sqruff # SQL formatter and linter
    stable.vimgolf # Vim golfing
  ];
}
