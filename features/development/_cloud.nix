{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.kubernetes-helm # Kubernetes package manager
    unstable.k9s # Kubernetes TUI
    unstable.kubeconform # Kubernetes manifest validator
    unstable.kubectl # Kubernetes CLI
    unstable.opentofu # Infrastructure as code
  ];
}
