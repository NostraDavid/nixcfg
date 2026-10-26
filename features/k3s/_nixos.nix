{
  config,
  pkgs,
  unstable,
  ...
}: let
  pocImage = pkgs.dockerTools.buildLayeredImage {
    name = "powerlan/k3s-poc";
    config = {
      User = "10001:10001";
      Cmd = ["${pkgs.python3}/bin/python3" "${./poc.py}"];
      Env = ["PYTHONDONTWRITEBYTECODE=1" "PYTHONUNBUFFERED=1"];
      ExposedPorts."8080/tcp" = {};
    };
  };
  agentImage = pkgs.dockerTools.buildLayeredImage {
    name = "powerlan/openbao-agent";
    config = {
      User = "10001:10001";
      Entrypoint = ["${pkgs.openbao}/bin/bao"];
    };
  };
  containerSecurity = {
    allowPrivilegeEscalation = false;
    readOnlyRootFilesystem = true;
    capabilities.drop = ["ALL"];
  };
  agentConfig = ''
    pid_file = "/run/openbao/agent.pid"
    vault {
      address = "https://192.168.2.112"
      ca_cert = "/etc/powerlan/ca.crt"
    }
    auto_auth {
      method "kubernetes" {
        mount_path = "auth/k3s"
        config = { role = "k3s-poc" }
      }
    }
    template_config {
      static_secret_render_interval = "30s"
    }
    template {
      contents = "{{ with secret \"services/data/k3s/poc\" }}{{ .Data.data | toJSON }}{{ end }}"
      destination = "/run/openbao/probe.json"
      perms = "0440"
      error_on_missing_key = true
      backup = false
    }
  '';
  namespace = "apps-poc";
in {
  environment.systemPackages = [pkgs.openssl];
  environment.etc."k3s-poc/policy.hcl".source = ./policy.hcl;
  services.k3s = {
    enable = true;
    package = unstable.k3s_1_36;
    role = "server";
    disable = ["servicelb"];
    extraFlags = [
      "--node-ip=192.168.2.106"
      "--advertise-address=192.168.2.106"
      "--write-kubeconfig-mode=0600"
      "--secrets-encryption"
      "--secrets-encryption-provider=secretbox"
    ];
    images = [pocImage agentImage config.services.k3s.package.airgap-images];
    manifests = {
      traefik-config.content = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChartConfig";
        metadata = {
          name = "traefik";
          namespace = "kube-system";
        };
        spec.valuesContent = builtins.toJSON {
          hostNetwork = true;
          deployment.dnsPolicy = "ClusterFirstWithHostNet";
          service.type = "ClusterIP";
          ports = {
            traefik.port = 9000;
            web = {
              port = 8080;
              exposedPort = 80;
            };
            websecure.expose.default = false;
          };
          ingressRoute.dashboard.enabled = false;
          resources = {
            requests = {
              cpu = "50m";
              memory = "64Mi";
            };
            limits.memory = "256Mi";
          };
        };
      };
      poc.content = [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = namespace;
            labels = {
              "pod-security.kubernetes.io/enforce" = "restricted";
              "pod-security.kubernetes.io/enforce-version" = "v1.36";
            };
          };
        }
        {
          apiVersion = "v1";
          kind = "ServiceAccount";
          metadata = {
            name = "poc";
            inherit namespace;
          };
          automountServiceAccountToken = false;
        }
        {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRole";
          metadata.name = "openbao-token-review";
          rules = [
            {
              apiGroups = ["authentication.k8s.io"];
              resources = ["tokenreviews"];
              verbs = ["create"];
            }
          ];
        }
        {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRoleBinding";
          metadata.name = "openbao-poc-token-review";
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "openbao-token-review";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "poc";
              inherit namespace;
            }
          ];
        }
        {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "openbao-agent";
            inherit namespace;
          };
          data = {
            "agent.hcl" = agentConfig;
            "ca.crt" = builtins.readFile ../../certs/forgejo-ca.crt;
          };
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "poc";
            inherit namespace;
          };
          spec = {
            replicas = 1;
            selector.matchLabels.app = "poc";
            template = {
              metadata.labels.app = "poc";
              spec = {
                serviceAccountName = "poc";
                automountServiceAccountToken = false;
                securityContext = {
                  runAsNonRoot = true;
                  runAsUser = 10001;
                  runAsGroup = 10001;
                  fsGroup = 10001;
                  seccompProfile.type = "RuntimeDefault";
                };
                containers = [
                  {
                    name = "web";
                    image = "${pocImage.imageName}:${pocImage.imageTag}";
                    imagePullPolicy = "Never";
                    ports = [
                      {
                        containerPort = 8080;
                        name = "http";
                      }
                    ];
                    env = [
                      {
                        name = "POD_NAME";
                        valueFrom.fieldRef.fieldPath = "metadata.name";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "secrets";
                        mountPath = "/run/openbao";
                        readOnly = true;
                      }
                    ];
                    securityContext = containerSecurity;
                    readinessProbe = {
                      httpGet = {
                        path = "/healthz";
                        port = "http";
                      };
                      periodSeconds = 5;
                    };
                    livenessProbe = {
                      tcpSocket.port = "http";
                      initialDelaySeconds = 10;
                      periodSeconds = 10;
                    };
                    resources = {
                      requests = {
                        cpu = "25m";
                        memory = "32Mi";
                      };
                      limits = {
                        cpu = "250m";
                        memory = "96Mi";
                      };
                    };
                  }
                  {
                    name = "openbao-agent";
                    image = "${agentImage.imageName}:${agentImage.imageTag}";
                    imagePullPolicy = "Never";
                    args = ["agent" "-config=/etc/openbao/agent.hcl"];
                    volumeMounts = [
                      {
                        name = "secrets";
                        mountPath = "/run/openbao";
                      }
                      {
                        name = "agent-config";
                        mountPath = "/etc/openbao";
                        readOnly = true;
                      }
                      {
                        name = "agent-config";
                        mountPath = "/etc/powerlan";
                        readOnly = true;
                      }
                      {
                        name = "identity";
                        mountPath = "/var/run/secrets/kubernetes.io/serviceaccount";
                        readOnly = true;
                      }
                    ];
                    securityContext = containerSecurity;
                    resources = {
                      requests = {
                        cpu = "25m";
                        memory = "64Mi";
                      };
                      limits = {
                        cpu = "250m";
                        memory = "192Mi";
                      };
                    };
                  }
                ];
                volumes = [
                  {
                    name = "secrets";
                    emptyDir = {
                      medium = "Memory";
                      sizeLimit = "1Mi";
                    };
                  }
                  {
                    name = "agent-config";
                    configMap.name = "openbao-agent";
                  }
                  {
                    name = "identity";
                    projected = {
                      defaultMode = 288;
                      sources = [
                        {
                          serviceAccountToken = {
                            path = "token";
                            expirationSeconds = 600;
                          };
                        }
                      ];
                    };
                  }
                ];
              };
            };
          };
        }
        {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "poc";
            inherit namespace;
          };
          spec = {
            selector.app = "poc";
            ports = [
              {
                port = 80;
                targetPort = "http";
              }
            ];
          };
        }
        {
          apiVersion = "networking.k8s.io/v1";
          kind = "Ingress";
          metadata = {
            name = "poc";
            inherit namespace;
          };
          spec = {
            ingressClassName = "traefik";
            rules = map (host: {
              inherit host;
              http.paths = [
                {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    name = "poc";
                    port.number = 80;
                  };
                }
              ];
            }) ["poc.apps.powerlan.empire" "ctb.apps.powerlan.empire" "huishoudboekje.apps.powerlan.empire" "recepten.apps.powerlan.empire"];
          };
        }
        {
          apiVersion = "networking.k8s.io/v1";
          kind = "NetworkPolicy";
          metadata = {
            name = "poc-isolation";
            inherit namespace;
          };
          spec = {
            podSelector.matchLabels.app = "poc";
            policyTypes = ["Ingress" "Egress"];
            ingress = [
              {
                from = [{ipBlock.cidr = "192.168.2.106/32";}];
                ports = [
                  {
                    protocol = "TCP";
                    port = 8080;
                  }
                ];
              }
            ];
            egress = [
              {
                to = [{ipBlock.cidr = "192.168.2.112/32";}];
                ports = [
                  {
                    protocol = "TCP";
                    port = 443;
                  }
                ];
              }
            ];
          };
        }
      ];
    };
  };
}
