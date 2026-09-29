# Evaluate an app VM configuration, including untracked local files.
[group('proxmox')]
app-vm-check host:
  @nix eval path:.#nixosConfigurations."{{host}}".config.system.build.toplevel.drvPath

# Evaluate the Proxmox app VM configurations.
[group('proxmox')]
app-vms-check:
  @just app-vm-check homepage
  @just app-vm-check apps
  @just app-vm-check forgejo
  @just app-vm-check proxy

# Deploy an app VM configuration to a remote NixOS guest.
[group('proxmox')]
app-vm-deploy host target:
  @nixos-rebuild switch --flake path:.#"{{host}}" --target-host "{{target}}" --use-remote-sudo

# Deploy the Homepage VM configuration.
[group('proxmox')]
deploy-homepage target="david@homepage":
  @just app-vm-deploy homepage "{{target}}"

# Deploy the shared apps VM configuration.
[group('proxmox')]
deploy-apps target="david@apps":
  @just app-vm-deploy apps "{{target}}"

# Deploy the Forgejo VM configuration.
[group('proxmox')]
deploy-forgejo target="david@192.168.2.110":
  @just app-vm-deploy forgejo "{{target}}"

# Deploy the shared proxy VM configuration.
[group('proxmox')]
deploy-proxy target="david@192.168.2.111":
  @just app-vm-deploy proxy "{{target}}"

# Check the Forgejo/FreeIPA LDAP prerequisites without changing accounts.
[group('proxmox')]
forgejo-ldap-check:
  @nix shell nixpkgs#openldap --command ./cmd/forgejo-ldap-bootstrap.sh --check

# Create the restricted FreeIPA bind account and configure Forgejo via LDAPS.
[group('proxmox')]
forgejo-ldap-bootstrap:
  @nix shell nixpkgs#openldap nixpkgs#krb5 --command ./cmd/forgejo-ldap-bootstrap.sh

# Format a Homepage state disk with the expected filesystem label.
[group('proxmox')]
format-homepage-data device:
  @sudo mkfs.ext4 -L homepage-data "{{device}}"

# Format the apps PostgreSQL state disk with the expected filesystem label.
[group('proxmox')]
format-apps-postgres device:
  @sudo mkfs.ext4 -L apps-postgres "{{device}}"

# Format the apps upload/state disk with the expected filesystem label.
[group('proxmox')]
format-apps-data device:
  @sudo mkfs.ext4 -L apps-data "{{device}}"

# Initialize OpenTofu for Proxmox VM management.
[group('tofu')]
tofu-proxmox-init:
  @tofu -chdir=infra/proxmox init

# Create a local Proxmox OpenTofu variables file from the example.
[group('tofu')]
tofu-proxmox-tfvars:
  @cp -n infra/proxmox/terraform.tfvars.example infra/proxmox/terraform.tfvars
  @${EDITOR:-nano} infra/proxmox/terraform.tfvars

# Format the Proxmox OpenTofu files.
[group('tofu')]
tofu-proxmox-fmt:
  @tofu fmt -recursive infra/proxmox

# Check Proxmox OpenTofu formatting.
[group('tofu')]
tofu-proxmox-fmt-check:
  @tofu fmt -check -recursive infra/proxmox

# Validate the Proxmox OpenTofu configuration.
[group('tofu')]
tofu-proxmox-validate:
  @tofu -chdir=infra/proxmox validate

# Show effective Proxmox permissions for the configured API token.
[group('tofu')]
tofu-proxmox-permissions:
  @./cmd/proxmox-permissions.sh

# Run non-network OpenTofu checks for the Proxmox stack.
[group('tofu')]
tofu-proxmox-check:
  @just tofu-proxmox-fmt-check
  @just tofu-proxmox-validate

# Plan Proxmox VM changes.
[group('tofu')]
tofu-proxmox-plan:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; test -s "$forgejo_image_dir/nixos.qcow2"; test -s "$proxy_image_dir/nixos.qcow2"; SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox plan

# Build the NixOS image and apply Proxmox VM changes.
[group('tofu')]
tofu-proxmox-apply:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; test -s "$forgejo_image_dir/nixos.qcow2"; test -s "$proxy_image_dir/nixos.qcow2"; SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox apply

# Show OpenTofu-managed Proxmox VM outputs.
[group('tofu')]
tofu-proxmox-output:
  @tofu -chdir=infra/proxmox output

# List resources in the Proxmox OpenTofu state.
[group('tofu')]
tofu-proxmox-state:
  @tofu -chdir=infra/proxmox state list

# Plan destroying OpenTofu-managed Proxmox resources.
[group('tofu')]
tofu-proxmox-plan-destroy:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox plan -destroy

# Destroy OpenTofu-managed Proxmox resources.
[group('tofu')]
tofu-proxmox-destroy:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox destroy
