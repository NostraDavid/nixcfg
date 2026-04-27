default_host := "wodan"

set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes and their parameters.
default:
  @just --list

# Format all Nix files in the repository.
format-alejandra:
   .

format-oxfmt:
   . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.json' -o -name '*.jsonc' \) -print0 | xargs -0 --no-run-if-empty oxfmt --write

format-shfmt:
   . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.sh' -o -name '.bashrc' -o -name '.bash_aliases' \) -print0 | xargs -0 --no-run-if-empty shfmt -w

format-ruff:
   format .

format:
   format-alejandra
   format-oxfmt
   format-shfmt
   format-ruff

fmt:
   format

# Update flake inputs in flake.lock.
update:
  nix flake update

# Update a local flake package via its updater or nix-update fallback.
pkg-update package:
  ./cmd/local-package-maint.sh update "{{package}}"

# List local packages with newer versions available.
pkg-updates *packages:
  ./cmd/local-package-maint.sh list {{packages}}

# Inspect the selected NixOS configuration from the flake.
nixos-show host=default_host:
   flake show .#nixosConfigurations."{{host}}"

# Run formatting checks without modifying files.
check:
   --check .
   . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.json' -o -name '*.jsonc' \) -print0 | xargs -0 --no-run-if-empty oxfmt --check
   . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.sh' -o -name '.bashrc' -o -name '.bash_aliases' \) -print0 | xargs -0 --no-run-if-empty shfmt -d
   format --check .

# Test a host configuration temporarily; reverts after reboot.
test host=default_host:
  sudo nixos-rebuild test --flake .#"{{host}}"

# Apply a host configuration immediately and persist across reboots.
switch host="":
  if [ -z "{{host}}" ]; then echo "Available hosts:"; nix eval --json .#nixosConfigurations --apply 'attrs: builtins.attrNames attrs' | jq -r '.[]' | sed 's/^/  /'; exit 1; fi
  sudo nixos-rebuild switch --flake .#"{{host}}"

# Stage a host configuration for the next boot only.
boot host=default_host:
  sudo nixos-rebuild boot --flake .#"{{host}}"

# Build a VM for the selected host configuration.
build-vm host=default_host:
  nixos-rebuild build-vm --flake .#"{{host}}"

# Evaluate an app VM configuration, including untracked local files.
app-vm-check host:
  nix eval path:.#nixosConfigurations."{{host}}".config.system.build.toplevel.drvPath

# Evaluate both Proxmox app VM configurations.
app-vms-check:
  just app-vm-check homepage
  just app-vm-check apps

# Deploy an app VM configuration to a remote NixOS guest.
app-vm-deploy host target:
  nixos-rebuild switch --flake path:.#"{{host}}" --target-host "{{target}}"

# Deploy the Homepage VM configuration.
deploy-homepage target="root@homepage":
  just app-vm-deploy homepage "{{target}}"

# Deploy the shared apps VM configuration.
deploy-apps target="root@apps":
  just app-vm-deploy apps "{{target}}"

# Format a Homepage state disk with the expected filesystem label.
format-homepage-data device:
  sudo mkfs.ext4 -L homepage-data "{{device}}"

# Format the apps PostgreSQL state disk with the expected filesystem label.
format-apps-postgres device:
  sudo mkfs.ext4 -L apps-postgres "{{device}}"

# Format the apps upload/state disk with the expected filesystem label.
format-apps-data device:
  sudo mkfs.ext4 -L apps-data "{{device}}"

# Initialize OpenTofu for Proxmox VM management.
tofu-proxmox-init:
  tofu -chdir=infra/proxmox init

# Create a local Proxmox OpenTofu variables file from the example.
tofu-proxmox-tfvars:
  cp -n infra/proxmox/terraform.tfvars.example infra/proxmox/terraform.tfvars
  ${EDITOR:-nano} infra/proxmox/terraform.tfvars

# Format the Proxmox OpenTofu files.
tofu-proxmox-fmt:
  tofu fmt -recursive infra/proxmox

# Check Proxmox OpenTofu formatting.
tofu-proxmox-fmt-check:
  tofu fmt -check -recursive infra/proxmox

# Validate the Proxmox OpenTofu configuration.
tofu-proxmox-validate:
  tofu -chdir=infra/proxmox validate

# Show effective Proxmox permissions for the configured API token.
tofu-proxmox-permissions:
  ./cmd/proxmox-permissions.sh

# Run non-network OpenTofu checks for the Proxmox stack.
tofu-proxmox-check:
  just tofu-proxmox-fmt-check
  just tofu-proxmox-validate

# Plan Proxmox VM changes.
tofu-proxmox-plan:
  tofu -chdir=infra/proxmox plan

# Apply Proxmox VM changes.
tofu-proxmox-apply:
  tofu -chdir=infra/proxmox apply

# Show OpenTofu-managed Proxmox VM outputs.
tofu-proxmox-output:
  tofu -chdir=infra/proxmox output

# List resources in the Proxmox OpenTofu state.
tofu-proxmox-state:
  tofu -chdir=infra/proxmox state list

# Plan destroying OpenTofu-managed Proxmox resources.
tofu-proxmox-plan-destroy:
  tofu -chdir=infra/proxmox plan -destroy

# Destroy OpenTofu-managed Proxmox resources.
tofu-proxmox-destroy:
  tofu -chdir=infra/proxmox destroy

# Show filesystem and Nix store usage quickly.
space:
  df -h /
  sudo du -sh /nix/store

# Show current GC roots (trimmed).
roots:
  sudo nix-store --gc --print-roots | sed -n '1,120p'

# Show the largest retained system generations.
system-gen-sizes:
  for p in /nix/var/nix/profiles/system-*-link; do readlink -f "$p"; done | sort -u | xargs -r nix path-info -Sh | sort -h | tail -n 20

# Delete all non-current generations (system + user), then garbage collect.
gc:
  sudo nix-collect-garbage -d
  nix-collect-garbage -d
  rm -f ./result

# Keep only recent generations by age, then garbage collect.
gc-old days="14":
  sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations "$(printf '%s' '{{days}}' | sed 's/d$//')d"
  home-manager expire-generations "-$(printf '%s' '{{days}}' | sed 's/d$//') days"
  nix-collect-garbage -d
  rm -f ./result

# Deduplicate identical files in /nix/store.
optimise-store:
  sudo nix store optimise

# Safer deploy when disk pressure is high.
switch-clean host=default_host days="14":
  just gc-old "{{days}}"
  just optimise-store
  sudo nixos-rebuild test --flake .#"{{host}}"
  sudo nixos-rebuild switch --flake .#"{{host}}"

precommit:
  @just lint

install-hooks:
  @prek install

lint-ruff:
  @ruff check .

lint-shellcheck:
  @find . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.sh' -o -name '.bashrc' -o -name '.bash_aliases' \) -print0 | xargs -0 --no-run-if-empty shellcheck --severity=info

lint-markdown:
  @find . -type d \( -name .git -o -name .direnv -o -name .venv \) -prune -o -type f -name '*.md' -print0 | xargs -0 --no-run-if-empty markdownlint

lint-statix:
  @statix check .

lint-deadnix:
  @deadnix .

lint:
  @just lint-ruff
  @just lint-shellcheck
  @just lint-markdown
  @just lint-statix
  @just lint-deadnix

precommit:
  @just lint

versions:
  @printf '%-14s %s\n' 'ruff:' "$(if command -v ruff >/dev/null 2>&1; then ruff --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'shellcheck:' "$(if command -v shellcheck >/dev/null 2>&1; then shellcheck --version | awk 'NR==2 {print $2; exit}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'markdownlint:' "$(if command -v markdownlint >/dev/null 2>&1; then markdownlint --version; else echo missing; fi)"
  @printf '%-14s %s\n' 'statix:' "$(if command -v statix >/dev/null 2>&1; then statix --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'deadnix:' "$(if command -v deadnix >/dev/null 2>&1; then deadnix --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'alejandra:' "$(if command -v alejandra >/dev/null 2>&1; then alejandra --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'oxfmt:' "$(if command -v oxfmt >/dev/null 2>&1; then oxfmt --version | awk '/Version:/ {print $2; exit}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'shfmt:' "$(if command -v shfmt >/dev/null 2>&1; then shfmt --version; else echo missing; fi)"
  @printf '%-14s %s\n' 'prek:' "$(if command -v prek >/dev/null 2>&1; then prek --version | awk '{print $2}'; else echo missing; fi)"
