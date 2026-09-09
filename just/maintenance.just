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
