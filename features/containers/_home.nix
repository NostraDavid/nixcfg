{
  local,
  stable,
  unstable,
  ...
}: {
  home.packages = [
    local.dockerfile-roast # Opinionated Dockerfile linter
    stable.hadolint # Dockerfile linter
    stable.k9s # Kubernetes terminal client
    stable.kdash # Kubernetes dashboard
    unstable.podman-compose # docker-compose alternative
    unstable.podman-desktop # GUI for managing containers
  ];
}
