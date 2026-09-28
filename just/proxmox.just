# Evaluate an app VM configuration, including untracked local files.
app-vm-check host:
  @nix eval path:.#nixosConfigurations."{{host}}".config.system.build.toplevel.drvPath

# Evaluate the Proxmox app VM configurations.
app-vms-check:
  @just app-vm-check homepage
  @just app-vm-check apps
  @just app-vm-check forgejo
  @just app-vm-check proxy

# Deploy an app VM configuration to a remote NixOS guest.
app-vm-deploy host target:
  @nixos-rebuild switch --flake path:.#"{{host}}" --target-host "{{target}}" --use-remote-sudo

# Deploy the Homepage VM configuration.
deploy-homepage target="david@homepage":
  @just app-vm-deploy homepage "{{target}}"

# Deploy the shared apps VM configuration.
deploy-apps target="david@apps":
  @just app-vm-deploy apps "{{target}}"

# Deploy the Forgejo VM configuration.
deploy-forgejo target="david@192.168.2.110":
  @just app-vm-deploy forgejo "{{target}}"

# Deploy the shared proxy VM configuration.
deploy-proxy target="david@192.168.2.111":
  @just app-vm-deploy proxy "{{target}}"

# Check the Forgejo/FreeIPA LDAP prerequisites without changing accounts.
forgejo-ldap-check:
  @nix shell nixpkgs#openldap --command ./cmd/forgejo-ldap-bootstrap.sh --check

# Create the restricted FreeIPA bind account and configure Forgejo via LDAPS.
forgejo-ldap-bootstrap:
  @nix shell nixpkgs#openldap --command ./cmd/forgejo-ldap-bootstrap.sh

# Format a Homepage state disk with the expected filesystem label.
format-homepage-data device:
  @sudo mkfs.ext4 -L homepage-data "{{device}}"

# Format the apps PostgreSQL state disk with the expected filesystem label.
format-apps-postgres device:
  @sudo mkfs.ext4 -L apps-postgres "{{device}}"

# Format the apps upload/state disk with the expected filesystem label.
format-apps-data device:
  @sudo mkfs.ext4 -L apps-data "{{device}}"

# Initialize OpenTofu for Proxmox VM management.
tofu-proxmox-init:
  @tofu -chdir=infra/proxmox init

# Create a local Proxmox OpenTofu variables file from the example.
tofu-proxmox-tfvars:
  @cp -n infra/proxmox/terraform.tfvars.example infra/proxmox/terraform.tfvars
  @${EDITOR:-nano} infra/proxmox/terraform.tfvars

# Format the Proxmox OpenTofu files.
tofu-proxmox-fmt:
  @tofu fmt -recursive infra/proxmox

# Check Proxmox OpenTofu formatting.
tofu-proxmox-fmt-check:
  @tofu fmt -check -recursive infra/proxmox

# Validate the Proxmox OpenTofu configuration.
tofu-proxmox-validate:
  @tofu -chdir=infra/proxmox validate

# Show effective Proxmox permissions for the configured API token.
tofu-proxmox-permissions:
  @./cmd/proxmox-permissions.sh

# Run non-network OpenTofu checks for the Proxmox stack.
tofu-proxmox-check:
  @just tofu-proxmox-fmt-check
  @just tofu-proxmox-validate

# Plan Proxmox VM changes.
tofu-proxmox-plan:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; test -s "$forgejo_image_dir/nixos.qcow2"; test -s "$proxy_image_dir/nixos.qcow2"; SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox plan

# Build the NixOS image and apply Proxmox VM changes.
tofu-proxmox-apply:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; test -s "$forgejo_image_dir/nixos.qcow2"; test -s "$proxy_image_dir/nixos.qcow2"; SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox apply

# Show OpenTofu-managed Proxmox VM outputs.
tofu-proxmox-output:
  @tofu -chdir=infra/proxmox output

# List resources in the Proxmox OpenTofu state.
tofu-proxmox-state:
  @tofu -chdir=infra/proxmox state list

# Plan destroying OpenTofu-managed Proxmox resources.
tofu-proxmox-plan-destroy:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox plan -destroy

# Destroy OpenTofu-managed Proxmox resources.
tofu-proxmox-destroy:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox destroy
