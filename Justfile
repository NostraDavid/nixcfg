default_host := "wodan"

set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes and their parameters.
default:
  @just --list

# Format all Nix files in the repository.
fmt:
  alejandra .

# Update flake inputs in flake.lock.
update:
  nix flake update

# Inspect the selected NixOS configuration from the flake.
check host=default_host:
  nix flake show .#nixosConfigurations."{{host}}"

# Test a host configuration temporarily; reverts after reboot.
test host=default_host:
  sudo nixos-rebuild test --flake .#"{{host}}"

# Apply a host configuration immediately and persist across reboots.
switch host=default_host:
  sudo nixos-rebuild switch --flake .#"{{host}}"

# Stage a host configuration for the next boot only.
boot host=default_host:
  sudo nixos-rebuild boot --flake .#"{{host}}"

# Build a VM for the selected host configuration.
build-vm host=default_host:
  nixos-rebuild build-vm --flake .#"{{host}}"

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
