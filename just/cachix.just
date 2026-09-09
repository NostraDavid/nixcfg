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
