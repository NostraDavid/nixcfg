{pkgs, ...}: let
  stable = pkgs;
  local = {inherit (pkgs) hermes-agent-desktop;};
in {
  home.packages = [
    stable.exfatprogs # ExFAT FS utilities
    stable.helm # Kubernetes package manager
    stable.k3d # k3s in docker
    stable.k3s # kubes (includes kubectl)
    stable.postgresql # for psql; there's pgcli for shared
    stable.redpanda-client # Kafka alternative
    stable.vimgolf # Vim golfing
    stable.dotnet-sdk # .NET development kit
    stable.sqruff # SQL formatter and linter
    local.hermes-agent-desktop # Desktop client for the Hermes coding agent
  ];
}
