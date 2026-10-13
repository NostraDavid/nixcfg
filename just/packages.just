# Update all flake inputs, including inputs nested under other inputs.
[group('packages')]
update:
  @source ./scripts/github-auth.sh; \
  {{nix_clean_env}} nix flake update --option http-connections 1; \
  nested_inputs="$(jq -r 'def paths($node; $prefix; $seen): . as $lock | ($lock.nodes[$node].inputs // {} | to_entries[]) as $input | select($input.value | type == "string") | ($prefix + [$input.key]) as $path | (if ($path | length) > 1 then ($path | join("/")) else empty end), (if ($seen | index($input.value)) == null then paths($input.value; $path; $seen + [$input.value]) else empty end); paths("root"; []; ["root"])' flake.lock | sort -u)"; \
  if [[ -n "$nested_inputs" ]]; then \
    mapfile -t nested_input_paths <<< "$nested_inputs"; \
    {{nix_clean_env}} nix flake update --option http-connections 1 "${nested_input_paths[@]}"; \
  fi

# Update nixpkgs and home-manager flake inputs in flake.lock.
[group('packages')]
update-nix:
  @source ./scripts/github-auth.sh; \
  for input in nixpkgs home-manager; do \
    {{nix_clean_env}} nix flake update --option http-connections 1 "$input"; \
    if [ "$input" = nixpkgs ]; then sleep "{{flake_update_delay_seconds}}"; fi; \
  done

# Update a local flake package via its updater or nix-update fallback.
[group('packages')]
pkg-update package:
  @./scripts/local-package-maint.sh update "{{package}}"

# Update every local flake package via its updater or nix-update fallback.
[group('packages')]
pkg-update-all:
  @packages="$(./scripts/local-package-maint.sh packages)" || exit $?; \
  red="$(printf '\033[31m')"; reset="$(printf '\033[0m')"; bold="$(printf '\033[1m')"; failures=(); \
  for package in $packages; do \
    if ! just pkg-update "$package"; then \
      failures+=("$package"); \
    fi; \
  done; \
  if [ ${#failures[@]} -gt 0 ]; then \
    printf '%s%sPackages with failed updates:%s\n' "$bold" "$red" "$reset" >&2; \
    printf '  %s\n' "${failures[@]}" >&2; \
    exit 1; \
  fi

# List local packages with newer versions available.
[group('packages')]
pkg-updates *packages:
  @./scripts/local-package-maint.sh list {{packages}}
