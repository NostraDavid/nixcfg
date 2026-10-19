{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.dotnet-sdk # .NET development kit
    stable.exfatprogs # ExFAT FS utilities
    stable.kubernetes-helm # Kubernetes package manager (Helm 3)
    stable.k3s # kubes (includes kubectl)
    stable.postgresql # for psql; there's pgcli for shared
    unstable.k3d # k3s in docker
    unstable.redpanda-client # Kafka alternative
    unstable.vimgolf # Vim golfing
  ];
}
