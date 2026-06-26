default_host := "wodan"
nix_clean_env := "env -u LD_LIBRARY_PATH -u NIX_LD_LIBRARY_PATH -u LD_PRELOAD"
audient_mic_source := "alsa_input.usb-Audient_Audient_iD4-00.HiFi__Mic__source"

set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes and their parameters.
default:
  @just --list

# Format all Nix files in the repository.
format-alejandra:
  @alejandra .

format-oxfmt:
  @find . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.json' -o -name '*.jsonc' \) -print0 | xargs -0 --no-run-if-empty oxfmt --write

format-shfmt:
  @find . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.sh' -o -name '.bashrc' -o -name '.bash_aliases' \) -print0 | xargs -0 --no-run-if-empty shfmt -w

format-ruff:
  @ruff format .

format:
  @just format-alejandra
  @just format-oxfmt
  @just format-shfmt
  @just format-ruff

fmt:
  @just format

# Update flake inputs in flake.lock.
update:
  @nix flake update

# Update nixpkgs and home-manager flake inputs in flake.lock.
update-nix:
  @{{nix_clean_env}} nix flake update nixpkgs home-manager

# Update a local flake package via its updater or nix-update fallback.
pkg-update package:
  @./cmd/local-package-maint.sh update "{{package}}"

# Update every local flake package via its updater or nix-update fallback.
pkg-update-all:
  @red="$$(printf '\033[31m')"; reset="$$(printf '\033[0m')"; bold="$$(printf '\033[1m')"; failures=(); \
  for package in $(nix eval --json .#packages.$(nix eval --impure --raw --expr 'builtins.currentSystem') --apply 'pkgs: builtins.attrNames pkgs' | jq -r '.[]'); do \
    if ! just pkg-update "$package"; then \
      failures+=("$package"); \
    fi; \
  done; \
  if [ ${#failures[@]} -gt 0 ]; then \
    printf '%s%sPackages with failed updates:%s\n' "$$bold" "$$red" "$$reset" >&2; \
    printf '  %s\n' "${failures[@]}" >&2; \
    exit 1; \
  fi

# List local packages with newer versions available.
pkg-updates *packages:
  @./cmd/local-package-maint.sh list {{packages}}

# Inspect the selected NixOS configuration from the flake.
nixos-show host=default_host:
  @nix flake show .#nixosConfigurations."{{host}}"

# Run formatting checks without modifying files.
check:
  @alejandra --check .
  @find . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.json' -o -name '*.jsonc' \) -print0 | xargs -0 --no-run-if-empty oxfmt --check
  @find . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.sh' -o -name '.bashrc' -o -name '.bash_aliases' \) -print0 | xargs -0 --no-run-if-empty shfmt -d
  @ruff format --check .

# Test a host configuration temporarily; reverts after reboot.
test host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild test "${opts[@]}" --flake .#"{{host}}"

# Apply a host configuration immediately and persist across reboots.
switch host="":
  @if [ -z "{{host}}" ]; then echo "Available hosts:"; nix eval --json .#nixosConfigurations --apply 'attrs: builtins.attrNames attrs' | jq -r '.[]' | sed 's/^/  /'; exit 1; fi
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild switch "${opts[@]}" --flake .#"{{host}}"

# Stage a host configuration for the next boot only.
boot host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild boot "${opts[@]}" --flake .#"{{host}}"

# Build a VM for the selected host configuration.
build-vm host=default_host:
  @nixos-rebuild build-vm --flake .#"{{host}}"

# Switch input to the default audio output monitor.
audio-output:
  @sink="$(pactl get-default-sink)"; \
  source="$sink.monitor"; \
  pactl set-default-source "$source"; \
  for output in $(pactl list source-outputs | awk '/^Source Output #/ {id = substr($3, 2)} /application.name = "Friture"/ {print id}'); do \
    pactl move-source-output "$output" "$source"; \
  done; \
  printf 'Default source: %s\n' "$source"

# Switch input to the Audient iD4 microphone.
audio-mic:
  @source="{{audient_mic_source}}"; \
  pactl set-default-source "$source"; \
  for output in $(pactl list source-outputs | awk '/^Source Output #/ {id = substr($3, 2)} /application.name = "Friture"/ {print id}'); do \
    pactl move-source-output "$output" "$source"; \
  done; \
  printf 'Default source: %s\n' "$source"

# Evaluate an app VM configuration, including untracked local files.
app-vm-check host:
  @nix eval path:.#nixosConfigurations."{{host}}".config.system.build.toplevel.drvPath

# Evaluate both Proxmox app VM configurations.
app-vms-check:
  @just app-vm-check homepage
  @just app-vm-check apps

# Deploy an app VM configuration to a remote NixOS guest.
app-vm-deploy host target:
  @nixos-rebuild switch --flake path:.#"{{host}}" --target-host "{{target}}"

# Deploy the Homepage VM configuration.
deploy-homepage target="root@homepage":
  @just app-vm-deploy homepage "{{target}}"

# Deploy the shared apps VM configuration.
deploy-apps target="root@apps":
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

# Show filesystem and Nix store usage quickly.
space:
  @df -h /
  @sudo du -sh /nix/store

# Show current GC roots (trimmed).
roots:
  @sudo nix-store --gc --print-roots | sed -n '1,120p'

# Show the largest retained system generations.
system-gen-sizes:
  @for p in /nix/var/nix/profiles/system-*-link; do readlink -f "$p"; done | sort -u | xargs -r nix path-info -Sh | sort -h | tail -n 20

# Delete all non-current generations (system + user), then garbage collect.
gc:
  @sudo nix-collect-garbage -d
  @nix-collect-garbage -d
  @rm -f ./result

# Keep only recent generations by age, then garbage collect.
gc-old days="14":
  @sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations "$(printf '%s' '{{days}}' | sed 's/d$//')d"
  @home-manager expire-generations "-$(printf '%s' '{{days}}' | sed 's/d$//') days"
  @nix-collect-garbage -d
  @rm -f ./result

# Deduplicate identical files in /nix/store.
optimise-store:
  @sudo nix store optimise

# Expire old Home Manager generations.
cleanup-home-manager older_than="30 days":
  @{{nix_clean_env}} home-manager expire-generations "{{older_than}}"

# Delete old Nix generations and run garbage collection.
cleanup-nix older_than="14d":
  @{{nix_clean_env}} nix-collect-garbage --delete-older-than {{older_than}}

# Garbage collect and optimise the Nix store.
cleanup-store:
  @{{nix_clean_env}} nix store gc
  @{{nix_clean_env}} nix store optimise

# Clean Home Manager generations, old Nix generations, and the store.
cleanup older_than_hm="30 days" older_than_nix="14d":
  @just cleanup-home-manager "{{older_than_hm}}"
  @just cleanup-nix {{older_than_nix}}
  @just cleanup-store

# Safer deploy when disk pressure is high.
switch-clean host=default_host days="14":
  @just gc-old "{{days}}"
  @just optimise-store
  @sudo nixos-rebuild test --flake .#"{{host}}"
  @sudo nixos-rebuild switch --flake .#"{{host}}"

install-hooks:
  @prek install

lint-ruff:
  @ruff check .

lint-shellcheck:
  @find . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \) -prune -o -type f \( -name '*.sh' -o -name '.bashrc' -o -name '.bash_aliases' \) -print0 | xargs -0 --no-run-if-empty shellcheck --severity=error

lint-markdown:
  @find . -type d \( -name .git -o -name .direnv -o -name .venv -o -name node_modules -o -name .terraform \) -prune -o -type f -name '*.md' -print0 | xargs -0 --no-run-if-empty markdownlint --disable MD013 MD040 MD041 --

lint-statix:
  @if command -v statix >/dev/null 2>&1; then statix check .; else nix develop --command statix check .; fi

lint-deadnix:
  @if command -v deadnix >/dev/null 2>&1; then deadnix .; else nix develop --command deadnix .; fi

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

security-target system="x86_64-linux":
  @target="$(nix build --no-link --print-out-paths .#nixosConfigurations.wodan.config.system.build.toplevel)"; \
  if [ -z "$target" ]; then echo "Failed to resolve NixOS system path" >&2; exit 1; fi; \
  printf '%s\n' "$target"

security-vulnix system="x86_64-linux" strict="false":
  @target="$(just security-target "{{system}}")"; \
  echo "Scanning $target with vulnix"; \
  rc=0; vulnix "$target" || rc=$?; \
  if [ "$rc" -eq 2 ] && [ "{{strict}}" != "true" ]; then echo "vulnix reported vulnerabilities; continuing because strict=false"; exit 0; fi; \
  exit "$rc"

security-sbom system="x86_64-linux" out_dir="reports/security":
  @report_dir="{{out_dir}}/{{system}}"; \
  target="$(just security-target "{{system}}")"; \
  mkdir -p "$report_dir"; \
  echo "Generating SBOM artifacts for $target in $report_dir"; \
  sbomnix "$target" --csv "$report_dir/sbom.csv" --cdx "$report_dir/sbom.cdx.json" --spdx "$report_dir/sbom.spdx.json"

security-osv system="x86_64-linux" out_dir="reports/security" format="table":
  @report_dir="{{out_dir}}/{{system}}"; \
  sbom="$report_dir/sbom.cdx.json"; \
  if [ ! -f "$sbom" ]; then echo "CycloneDX SBOM ontbreekt, genereer die eerst in $report_dir" >&2; exit 1; fi; \
  echo "Scanning $sbom with osv-scanner"; \
  osv-scanner scan source -L "$sbom" --format "{{format}}"

security-grype system="x86_64-linux" out_dir="reports/security" fail_on="":
  @report_dir="{{out_dir}}/{{system}}"; \
  sbom="$report_dir/sbom.cdx.json"; \
  if [ ! -f "$sbom" ]; then echo "CycloneDX SBOM ontbreekt, genereer die eerst in $report_dir" >&2; exit 1; fi; \
  if [ -n "{{fail_on}}" ]; then grype "sbom:$sbom" --fail-on "{{fail_on}}"; else grype "sbom:$sbom"; fi

security-smoke system="x86_64-linux":
  @just security-sbom "{{system}}" reports/security-smoke
  @just security-osv "{{system}}" reports/security-smoke
  @just security-grype "{{system}}" reports/security-smoke critical
