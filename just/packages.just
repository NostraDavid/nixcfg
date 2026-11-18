# Update all flake inputs, including inputs nested under other inputs.
[group('packages')]
[script("python3", "scripts/update-review.py", "update")]
update:
    just forgejo-support-warning
    source ./scripts/github-auth.sh
    {{nix_clean_env}} nix flake update --option http-connections 1
    nested_inputs="$(jq -r 'def paths($node; $prefix; $seen): . as $lock | ($lock.nodes[$node].inputs // {} | to_entries[]) as $input | select($input.value | type == "string") | ($prefix + [$input.key]) as $path | (if ($path | length) > 1 then ($path | join("/")) else empty end), (if ($seen | index($input.value)) == null then paths($input.value; $path; $seen + [$input.value]) else empty end); paths("root"; []; ["root"])' flake.lock | sort -u)"
    if [[ -n "$nested_inputs" ]]; then
        mapfile -t nested_input_paths <<< "$nested_inputs"
        {{nix_clean_env}} nix flake update --option http-connections 1 "${nested_input_paths[@]}"
    fi

# Update nixpkgs and home-manager flake inputs in flake.lock.
[group('packages')]
update-nix:
  @just forgejo-support-warning; \
  source ./scripts/github-auth.sh; \
  for input in nixpkgs home-manager; do \
    {{nix_clean_env}} nix flake update --option http-connections 1 "$input"; \
    if [ "$input" = nixpkgs ]; then sleep "{{flake_update_delay_seconds}}"; fi; \
  done

# Update a local flake package via its updater or nix-update fallback.
[group('packages')]
pkg-update package:
  @./scripts/local-package-maint.sh update "{{package}}"

# Update every local flake package via its updater or nix-update fallback.
# Keep console output and per-package updater logs under /tmp/just-pkgs.*.
# shortcut: detects tracked changes only, use explicit updater results if untracked files must count.
[group('packages')]
[script("python3", "scripts/update-review.py", "pkgs")]
pkgs:
    export NIXCFG_SKIP_UNCHANGED=1
    packages="$(./scripts/local-package-maint.sh packages)" || exit $?
    set -f
    set -- $packages
    red="$(printf '\033[31m')"; green="$(printf '\033[32m')"; blue="$(printf '\033[34m')"; reset="$(printf '\033[0m')"; bold="$(printf '\033[1m')"; failures=()
    for package in "$@"; do
      [[ "$package" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+-]*$ ]] || { echo "Invalid package name: $package" >&2; exit 2; }
      update_log="$log_dir/$package.log"
      printf '%s ... ' "$package"
      before="$(git diff --no-ext-diff --binary | git hash-object --stdin)"
      if just pkg-update "$package" >"$update_log" 2>&1; then
        after="$(git diff --no-ext-diff --binary | git hash-object --stdin)"
        if [ "$before" != "$after" ]; then printf '%supdated%s\n' "$blue" "$reset"; else printf '%sno update%s\n' "$green" "$reset"; fi
      else
        printf '%sFAILED%s\n' "$red" "$reset"
        cat "$update_log" >&2
        failures+=("$package")
      fi
    done
    if [ ${#failures[@]} -gt 0 ]; then
      printf '%s\n' "${failures[@]}" >"$log_dir/failed-packages"
      printf '%s%sPackages with failed updates:%s\n' "$bold" "$red" "$reset" >&2
      printf '  %s\n' "${failures[@]}" >&2
      exit 1
    fi

# List newer versions via GitHub release tags for prebuilt packages, or trial updates for other packages.
[group('packages')]
pkg-updates *packages:
  @./scripts/local-package-maint.sh list {{packages}}
