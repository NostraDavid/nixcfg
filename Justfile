default_host := `hostname --short`
default_cachix_cache := "thaumatorium"
nix_clean_env := "env -u LD_LIBRARY_PATH -u NIX_LD_LIBRARY_PATH -u LD_PRELOAD"
audient_mic_source := "alsa_input.usb-Audient_Audient_iD4-00.HiFi__Mic__source"

set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes and their parameters.
default:
  @just --list

# Format all Nix files in the repository.
format-alejandra:
  @git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty alejandra

format-oxfmt:
  @git ls-files -z -- '*.json' '*.jsonc' | xargs -0 --no-run-if-empty oxfmt --write

format-shfmt:
  @git ls-files -z -- '*.sh' '.bashrc' '.bash_aliases' | xargs -0 --no-run-if-empty shfmt -w

format-stylua:
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty stylua

format-ruff:
  @git ls-files -z -- '*.py' 'dotfiles/git/.config/git/hooks/commit-msg' | xargs -0 --no-run-if-empty ruff format

format:
  @just format-alejandra
  @just format-oxfmt
  @just format-shfmt
  @just format-stylua
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

# Build a local flake package and push its output to Cachix.
cachix-push package cache=default_cachix_cache:
  @path="$(nix build --print-out-paths .#"{{package}}")"; \
  cachix push "{{cache}}" "$path"

# Build all local flake packages and push their outputs to Cachix.
cachix-push-all cache=default_cachix_cache:
  @system="$(nix eval --impure --raw --expr 'builtins.currentSystem')"; \
  mapfile -t refs < <(nix eval --json .#packages.$system --apply 'pkgs: builtins.attrNames pkgs' | jq -r '.[] | ".#\(.)"'); \
  nix build --no-link --print-out-paths "${refs[@]}" | cachix push "{{cache}}"

# Build, push, and pin a local flake package in Cachix forever.
cachix-pin package cache=default_cachix_cache:
  @path="$(nix build --print-out-paths .#"{{package}}")"; \
  cachix push "{{cache}}" "$path"; \
  cachix pin "{{cache}}" "{{package}}" "$path" --keep-forever

# Build, push, and pin the current Codex package in Cachix forever.
cachix-pin-codex cache=default_cachix_cache:
  @just cachix-pin codex "{{cache}}"

# List Cachix pins for a cache.
cachix-pins cache=default_cachix_cache:
  @token="$(sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' ~/.config/cachix/cachix.dhall | head -n1)"; \
  curl -fsSL -H "Authorization: Bearer $token" "https://app.cachix.org/api/v1/cache/{{cache}}/pin" \
    | jq -r 'if length == 0 then "No pins." else .[] | "\(.name)\t\(.keep | @json)\t\(.createdOn)" end'

# Remove a Cachix pin by name.
cachix-unpin pin cache=default_cachix_cache:
  @token="$(sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' ~/.config/cachix/cachix.dhall | head -n1)"; \
  curl -fsSL -X DELETE -H "Authorization: Bearer $token" "https://app.cachix.org/api/v1/cache/{{cache}}/pin/{{pin}}"; \
  printf 'Unpinned %s from %s\n' "{{pin}}" "{{cache}}"

# Inspect the selected NixOS configuration from the flake.
nixos-show host=default_host:
  @nix flake show .#nixosConfigurations."{{host}}"

# Run formatting checks without modifying files.
check:
  @git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty alejandra --check
  @git ls-files -z -- '*.json' '*.jsonc' | xargs -0 --no-run-if-empty oxfmt --check
  @git ls-files -z -- '*.sh' '.bashrc' '.bash_aliases' | xargs -0 --no-run-if-empty shfmt -d
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty stylua --check
  @git ls-files -z -- '*.py' 'dotfiles/git/.config/git/hooks/commit-msg' | xargs -0 --no-run-if-empty ruff format --check

# Test a host configuration temporarily; reverts after reboot.
test host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild test "${opts[@]}" --flake path:.#"{{host}}"

# Apply a host configuration immediately and persist across reboots.
switch host=`hostname --short`:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild switch "${opts[@]}" --flake path:.#"{{host}}"

# Stage a host configuration for the next boot only.
boot host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild boot "${opts[@]}" --flake path:.#"{{host}}"

# Build a VM for the selected host configuration.
build-vm host=default_host:
  @nixos-rebuild build-vm --flake path:.#"{{host}}"

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

hooks-run:
  @prek --config .pre-commit-config.yaml run --all-files

lint-ruff:
  @git ls-files -z -- '*.py' 'dotfiles/git/.config/git/hooks/commit-msg' | grep -zv '^dotfiles/agents/\.agents/skills/' | xargs -0 --no-run-if-empty ruff check

lint-ruff-files *files:
  @printf '%s\0' {{files}} | { grep -zv '^dotfiles/agents/\.agents/skills/' || true; } | xargs -0 --no-run-if-empty ruff check

lint-shellcheck:
  @git ls-files -z -- '*.sh' '.bashrc' '.bash_aliases' | xargs -0 --no-run-if-empty shellcheck --severity=error

lint-shellcheck-files *files:
  @shellcheck --severity=error {{files}}

lint-markdown:
  @git ls-files -z -- '*.md' | grep -zEv '^(docs/agentskills\.io/|dotfiles/agents/\.agents/skills/)' | xargs -0 --no-run-if-empty markdownlint --disable MD013 MD040 MD041 --

lint-markdown-files *files:
  @printf '%s\0' {{files}} | { grep -zv '^dotfiles/agents/\.agents/skills/' || true; } | xargs -0 --no-run-if-empty markdownlint --disable MD013 MD040 MD041 --

lint-selene:
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty selene

lint-selene-files *files:
  @selene {{files}}

lint-statix:
  @cmd=(statix check); \
  if ! command -v statix >/dev/null 2>&1; then cmd=(nix develop --command statix check); fi; \
  git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty -n1 "${cmd[@]}"

lint-statix-files *files:
  @cmd=(statix check); \
  if ! command -v statix >/dev/null 2>&1; then cmd=(nix develop --command statix check); fi; \
  for file in {{files}}; do "${cmd[@]}" "$file"; done

lint-deadnix:
  @cmd=(deadnix --fail); \
  if ! command -v deadnix >/dev/null 2>&1; then cmd=(nix develop --command deadnix --fail); fi; \
  git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty "${cmd[@]}"

lint-deadnix-files *files:
  @cmd=(deadnix --fail); \
  if ! command -v deadnix >/dev/null 2>&1; then cmd=(nix develop --command deadnix --fail); fi; \
  "${cmd[@]}" {{files}}

lint:
  @just lint-ruff
  @just lint-shellcheck
  @just lint-markdown
  @just lint-selene
  @just lint-statix
  @just lint-deadnix

precommit:
  @just hooks-run

versions:
  @printf '%-14s %s\n' 'ruff:' "$(if command -v ruff >/dev/null 2>&1; then ruff --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'shellcheck:' "$(if command -v shellcheck >/dev/null 2>&1; then shellcheck --version | awk 'NR==2 {print $2; exit}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'markdownlint:' "$(if command -v markdownlint >/dev/null 2>&1; then markdownlint --version; else echo missing; fi)"
  @printf '%-14s %s\n' 'stylua:' "$(if command -v stylua >/dev/null 2>&1; then stylua --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'selene:' "$(if command -v selene >/dev/null 2>&1; then selene --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'lua-ls:' "$(if command -v lua-language-server >/dev/null 2>&1; then lua-language-server --version 2>&1 | awk 'NR==1 {print $NF; exit}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'statix:' "$(if command -v statix >/dev/null 2>&1; then echo installed; else echo missing; fi)"
  @printf '%-14s %s\n' 'deadnix:' "$(if command -v deadnix >/dev/null 2>&1; then deadnix --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'alejandra:' "$(if command -v alejandra >/dev/null 2>&1; then alejandra --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'oxfmt:' "$(if command -v oxfmt >/dev/null 2>&1; then oxfmt --version | awk '/Version:/ {print $2; exit}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'shfmt:' "$(if command -v shfmt >/dev/null 2>&1; then shfmt --version; else echo missing; fi)"
  @printf '%-14s %s\n' 'prek:' "$(if command -v prek >/dev/null 2>&1; then prek -V | awk '{print $2}'; else echo missing; fi)"

security-target host=default_host:
  @target="$(nix build --no-link --print-out-paths .#nixosConfigurations.\"{{host}}\".config.system.build.toplevel)"; \
  if [ -z "$target" ]; then echo "Failed to resolve NixOS system path" >&2; exit 1; fi; \
  printf '%s\n' "$target"

security-vulnix host=default_host strict="false":
  @target="$(just security-target "{{host}}")"; \
  echo "Scanning $target with vulnix"; \
  rc=0; vulnix "$target" || rc=$?; \
  if [ "$rc" -eq 2 ] && [ "{{strict}}" != "true" ]; then echo "vulnix reported vulnerabilities; continuing because strict=false"; exit 0; fi; \
  exit "$rc"

security-sbom host=default_host out_dir="reports/security":
  @report_dir="{{out_dir}}/{{host}}"; \
  target="$(just security-target "{{host}}")"; \
  mkdir -p "$report_dir"; \
  echo "Generating SBOM artifacts for $target in $report_dir"; \
  sbomnix "$target" --csv "$report_dir/sbom.csv" --cdx "$report_dir/sbom.cdx.json" --spdx "$report_dir/sbom.spdx.json"

security-osv host=default_host out_dir="reports/security" format="table":
  @report_dir="{{out_dir}}/{{host}}"; \
  sbom="$report_dir/sbom.cdx.json"; \
  if [ ! -f "$sbom" ]; then echo "CycloneDX SBOM ontbreekt, genereer die eerst in $report_dir" >&2; exit 1; fi; \
  echo "Scanning $sbom with osv-scanner"; \
  osv-scanner scan source -L "$sbom" --format "{{format}}"

security-grype host=default_host out_dir="reports/security" fail_on="":
  @report_dir="{{out_dir}}/{{host}}"; \
  sbom="$report_dir/sbom.cdx.json"; \
  if [ ! -f "$sbom" ]; then echo "CycloneDX SBOM ontbreekt, genereer die eerst in $report_dir" >&2; exit 1; fi; \
  if [ -n "{{fail_on}}" ]; then grype "sbom:$sbom" --fail-on "{{fail_on}}"; else grype "sbom:$sbom"; fi

security-smoke host=default_host:
  @just security-sbom "{{host}}" reports/security-smoke
  @just security-osv "{{host}}" reports/security-smoke
  @just security-grype "{{host}}" reports/security-smoke critical
