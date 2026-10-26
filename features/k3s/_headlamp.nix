{
  lib,
  pkgs,
  unstable,
  ...
}: let
  oidc = builtins.fromJSON (builtins.readFile ./headlamp-oidc.json);
  ca = builtins.readFile ../../certs/forgejo-ca.crt;
  security = {
    allowPrivilegeEscalation = false;
    readOnlyRootFilesystem = true;
    capabilities.drop = ["ALL"];
  };
  image = pkgs.dockerTools.buildLayeredImage {
    name = "powerlan/headlamp";
    contents = [unstable.headlamp-server unstable.headlamp-frontend];
    extraCommands = "mkdir -p plugins user-plugins";
    config = {
      User = "10001:10001";
      Entrypoint = ["${unstable.headlamp-server}/bin/headlamp-server"];
      Env = ["HOME=/state" "TMPDIR=/state" "SSL_CERT_FILE=/etc/headlamp/ca.crt"];
      ExposedPorts."4466/tcp" = {};
      WorkingDir = "/state";
    };
  };
  args = [
    "-in-cluster"
    "-html-static-dir=${unstable.headlamp-frontend}"
    "-plugins-dir=/plugins"
    "-user-plugins-dir=/user-plugins"
    "-watch-plugins-changes=false"
    "-oidc-client-id=${oidc.client_id}"
    "-oidc-idp-issuer-url=${oidc.issuer}"
    "-oidc-scopes=k3s"
    "-oidc-use-pkce"
    "-oidc-ca-file=/etc/headlamp/ca.crt"
    "-oidc-callback-url=https://k3s.powerlan.empire/oidc-callback"
    "-session-ttl=900"
    "-unsafe-use-service-account-token=false"
    "-log-level=warn"
  ];
  namespace = "headlamp";
  group = "freeipa:grp-infra-admin";
  binding = {
    name,
    role,
    kind ? "ClusterRole",
    ns ? null,
  }: {
    apiVersion = "rbac.authorization.k8s.io/v1";
    kind =
      if ns == null
      then "ClusterRoleBinding"
      else "RoleBinding";
    metadata = {inherit name;} // lib.optionalAttrs (ns != null) {namespace = ns;};
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io";
      inherit kind;
      name = role;
    };
    subjects = [
      {
        kind = "Group";
        name = group;
        apiGroup = "rbac.authorization.k8s.io";
      }
    ];
  };
in {
  assertions = [
    {
      assertion =
        builtins.match "[A-Za-z0-9]{32}" oidc.client_id
        != null
        && oidc.issuer == "https://openbao.powerlan.empire/v1/identity/oidc/provider/k3s";
      message = "Bootstrap the public Headlamp OIDC registration before deploying K3s.";
    }
  ];
  environment.etc."kubernetes/headlamp-authentication.json".text = builtins.toJSON {
    apiVersion = "apiserver.config.k8s.io/v1";
    kind = "AuthenticationConfiguration";
    jwt = [
      {
        issuer = {
          url = oidc.issuer;
          audiences = [oidc.client_id];
          certificateAuthority = ca;
        };
        claimValidationRules = [
          {
            expression = ''claims.preferred_username.endsWith("-adm")'';
            message = "A FreeIPA -adm account is required";
          }
          {
            expression = ''"grp-infra-admin" in claims.groups'';
            message = "FreeIPA infrastructure group membership is required";
          }
        ];
        claimMappings = {
          username = {
            claim = "preferred_username";
            prefix = "freeipa:";
          };
          groups = {
            claim = "groups";
            prefix = "freeipa:";
          };
          uid.claim = "sub";
        };
      }
    ];
  };
  services.k3s = {
    extraFlags = ["--kube-apiserver-arg=authentication-config=/etc/kubernetes/headlamp-authentication.json"];
    images = [image];
    manifests.headlamp.content = [
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
          name = "headlamp";
          inherit namespace;
        };
        automountServiceAccountToken = false;
      }
      {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "headlamp-ca";
          inherit namespace;
        };
        data."ca.crt" = ca;
      }
      {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "headlamp";
          inherit namespace;
        };
        spec = {
          replicas = 1;
          selector.matchLabels.app = "headlamp";
          template = {
            metadata.labels.app = "headlamp";
            spec = {
              serviceAccountName = "headlamp";
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
                  name = "headlamp";
                  image = "${image.imageName}:${image.imageTag}";
                  imagePullPolicy = "Never";
                  inherit args;
                  ports = [
                    {
                      name = "http";
                      containerPort = 4466;
                    }
                  ];
                  securityContext = security;
                  volumeMounts = [
                    {
                      name = "state";
                      mountPath = "/state";
                    }
                    {
                      name = "ca";
                      mountPath = "/etc/headlamp";
                      readOnly = true;
                    }
                    {
                      name = "identity";
                      mountPath = "/var/run/secrets/kubernetes.io/serviceaccount";
                      readOnly = true;
                    }
                  ];
                  readinessProbe = {
                    httpGet = {
                      path = "/";
                      port = "http";
                    };
                    periodSeconds = 5;
                  };
                  livenessProbe = {
                    tcpSocket.port = "http";
                    initialDelaySeconds = 15;
                    periodSeconds = 10;
                  };
                  resources = {
                    requests = {
                      cpu = "50m";
                      memory = "128Mi";
                    };
                    limits = {
                      cpu = "1";
                      memory = "512Mi";
                    };
                  };
                }
              ];
              volumes = [
                {
                  name = "state";
                  emptyDir = {
                    medium = "Memory";
                    sizeLimit = "128Mi";
                  };
                }
                {
                  name = "ca";
                  configMap.name = "headlamp-ca";
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
                      {
                        configMap = {
                          name = "kube-root-ca.crt";
                          items = [
                            {
                              key = "ca.crt";
                              path = "ca.crt";
                            }
                          ];
                        };
                      }
                      {
                        downwardAPI.items = [
                          {
                            path = "namespace";
                            fieldRef.fieldPath = "metadata.namespace";
                          }
                        ];
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
          name = "headlamp";
          inherit namespace;
        };
        spec = {
          selector.app = "headlamp";
          ports = [
            {
              port = 80;
              targetPort = "http";
            }
          ];
        };
      }
      {
        apiVersion = "traefik.io/v1alpha1";
        kind = "Middleware";
        metadata = {
          name = "https";
          inherit namespace;
        };
        spec.headers.customRequestHeaders."X-Forwarded-Proto" = "https";
      }
      {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "headlamp";
          inherit namespace;
          annotations."traefik.ingress.kubernetes.io/router.middlewares" = "headlamp-https@kubernetescrd";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            {
              host = "k3s.powerlan.empire";
              http.paths = [
                {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    name = "headlamp";
                    port.number = 80;
                  };
                }
              ];
            }
          ];
        };
      }
      {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRole";
        metadata.name = "headlamp-view";
        rules = [
          {
            apiGroups = [""];
            resources = ["nodes" "namespaces" "pods" "pods/log" "services" "endpoints" "configmaps" "serviceaccounts" "persistentvolumeclaims" "persistentvolumes" "events" "resourcequotas" "limitranges"];
            verbs = ["get" "list" "watch"];
          }
          {
            apiGroups = ["apps"];
            resources = ["deployments" "replicasets" "statefulsets" "daemonsets" "controllerrevisions"];
            verbs = ["get" "list" "watch"];
          }
          {
            apiGroups = ["batch"];
            resources = ["jobs" "cronjobs"];
            verbs = ["get" "list" "watch"];
          }
          {
            apiGroups = ["networking.k8s.io"];
            resources = ["ingresses" "ingressclasses" "networkpolicies"];
            verbs = ["get" "list" "watch"];
          }
          {
            apiGroups = ["metrics.k8s.io"];
            resources = ["nodes" "pods"];
            verbs = ["get" "list"];
          }
          {
            apiGroups = ["storage.k8s.io"];
            resources = ["storageclasses" "volumeattachments" "csidrivers" "csinodes"];
            verbs = ["get" "list" "watch"];
          }
          {
            apiGroups = ["autoscaling"];
            resources = ["horizontalpodautoscalers"];
            verbs = ["get" "list" "watch"];
          }
        ];
      }
      (binding {
        name = "headlamp-infra-view";
        role = "headlamp-view";
      })
      {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "Role";
        metadata = {
          name = "headlamp-app-operator";
          namespace = "apps-poc";
        };
        rules = [
          {
            apiGroups = [""];
            resources = ["pods"];
            verbs = ["delete"];
          }
          {
            apiGroups = ["apps"];
            resources = ["deployments/scale" "statefulsets/scale" "replicasets/scale"];
            verbs = ["get" "update" "patch"];
          }
        ];
      }
      (binding {
        name = "headlamp-infra-app-operator";
        role = "headlamp-app-operator";
        kind = "Role";
        ns = "apps-poc";
      })
      {
        apiVersion = "networking.k8s.io/v1";
        kind = "NetworkPolicy";
        metadata = {
          name = "headlamp-isolation";
          inherit namespace;
        };
        spec = {
          podSelector.matchLabels.app = "headlamp";
          policyTypes = ["Ingress" "Egress"];
          ingress = [
            {
              from = [{ipBlock.cidr = "192.168.2.106/32";}];
              ports = [
                {
                  protocol = "TCP";
                  port = 4466;
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
            {
              to = [{ipBlock.cidr = "192.168.2.106/32";}];
              ports = [
                {
                  protocol = "TCP";
                  port = 6443;
                }
              ];
            }
            {
              to = [{ipBlock.cidr = "10.43.0.1/32";}];
              ports = [
                {
                  protocol = "TCP";
                  port = 443;
                }
              ];
            }
            {
              to = [
                {
                  namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "kube-system";
                  podSelector.matchLabels."k8s-app" = "kube-dns";
                }
              ];
              ports = [
                {
                  protocol = "UDP";
                  port = 53;
                }
                {
                  protocol = "TCP";
                  port = 53;
                }
              ];
            }
          ];
        };
      }
    ];
  };
}
