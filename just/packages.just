# Update flake inputs in flake.lock.
update:
  @inputs="$(nix flake metadata --no-write-lock-file --json | jq -r '.locks.nodes.root.inputs | keys[]')"; \
  first=true; \
  while IFS= read -r input; do \
    if [ "$first" = false ]; then sleep "{{flake_update_delay_seconds}}"; fi; \
    printf 'Updating flake input: %s\n' "$input"; \
    {{nix_clean_env}} nix flake update --option http-connections 1 "$input"; \
    first=false; \
  done <<< "$inputs"

# Update nixpkgs and home-manager flake inputs in flake.lock.
update-nix:
  @for input in nixpkgs home-manager; do \
    {{nix_clean_env}} nix flake update --option http-connections 1 "$input"; \
    if [ "$input" = nixpkgs ]; then sleep "{{flake_update_delay_seconds}}"; fi; \
  done

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
