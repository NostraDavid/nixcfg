# Evaluate an app VM configuration, including untracked local files.
app-vm-check host:
  @nix eval path:.#nixosConfigurations."{{host}}".config.system.build.toplevel.drvPath

# Evaluate both Proxmox app VM configurations.
app-vms-check:
  @just app-vm-check homepage
  @just app-vm-check apps

# Deploy an app VM configuration to a remote NixOS guest.
app-vm-deploy host target:
  @nixos-rebuild switch --flake path:.#"{{host}}" --target-host "{{target}}" --use-remote-sudo

# Deploy the Homepage VM configuration.
deploy-homepage target="david@homepage":
  @just app-vm-deploy homepage "{{target}}"

# Deploy the shared apps VM configuration.
deploy-apps target="david@apps":
  @just app-vm-deploy apps "{{target}}"

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
  @tofu -chdir=infra/proxmox plan

# Apply Proxmox VM changes.
tofu-proxmox-apply:
  @tofu -chdir=infra/proxmox apply

# Show OpenTofu-managed Proxmox VM outputs.
tofu-proxmox-output:
  @tofu -chdir=infra/proxmox output

# List resources in the Proxmox OpenTofu state.
tofu-proxmox-state:
  @tofu -chdir=infra/proxmox state list

# Plan destroying OpenTofu-managed Proxmox resources.
tofu-proxmox-plan-destroy:
  @tofu -chdir=infra/proxmox plan -destroy

# Destroy OpenTofu-managed Proxmox resources.
tofu-proxmox-destroy:
  @tofu -chdir=infra/proxmox destroy
