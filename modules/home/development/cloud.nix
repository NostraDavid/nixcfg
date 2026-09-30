{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.k9s # Kubernetes TUI
    stable.kubeconform # Kubernetes manifest validator
    unstable.kubectl # Kubernetes CLI
    stable.kubernetes-helm # Kubernetes package manager
    stable.opentofu # Infrastructure as code
  ];
}
