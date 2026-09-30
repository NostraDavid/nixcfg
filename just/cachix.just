# Build a local flake package and push its output to Cachix.
[group('cachix')]
cachix-push package cache=default_cachix_cache:
  @path="$(nix build --print-out-paths .#"{{package}}")"; \
  cachix push "{{cache}}" "$path"

# Build all local flake packages and push their outputs to Cachix.
[group('cachix')]
cachix-push-all cache=default_cachix_cache:
  @system="$(nix eval --impure --raw --expr 'builtins.currentSystem')"; \
  mapfile -t refs < <(nix eval --json .#packages.$system --apply 'pkgs: builtins.attrNames pkgs' | jq -r '.[] | ".#\(.)"'); \
  nix build --no-link --print-out-paths "${refs[@]}" | cachix push "{{cache}}"

# Build, push, and pin a local flake package in Cachix forever.
[group('cachix')]
cachix-pin package cache=default_cachix_cache:
  @path="$(nix build --print-out-paths .#"{{package}}")"; \
  cachix push "{{cache}}" "$path"; \
  cachix pin "{{cache}}" "{{package}}" "$path" --keep-forever

# Build, push, and pin the current Codex package in Cachix forever.
[group('cachix')]
cachix-pin-codex cache=default_cachix_cache:
  @just cachix-pin codex "{{cache}}"

# List Cachix pins for a cache.
[group('cachix')]
cachix-pins cache=default_cachix_cache:
  @token="$(sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' ~/.config/cachix/cachix.dhall | head -n1)"; \
  curl -fsSL -H "Authorization: Bearer $token" "https://app.cachix.org/api/v1/cache/{{cache}}/pin" \
    | jq -r 'if length == 0 then "No pins." else .[] | "\(.name)\t\(.keep | @json)\t\(.createdOn)" end'

# Remove a Cachix pin by name.
[group('cachix')]
cachix-unpin pin cache=default_cachix_cache:
  @token="$(sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' ~/.config/cachix/cachix.dhall | head -n1)"; \
  curl -fsSL -X DELETE -H "Authorization: Bearer $token" "https://app.cachix.org/api/v1/cache/{{cache}}/pin/{{pin}}"; \
  printf 'Unpinned %s from %s\n' "{{pin}}" "{{cache}}"

# Clear all store paths and pins while retaining the cache and its signing key.
[group('cachix')]
cachix-clear cache=default_cachix_cache:
  #!/usr/bin/env bash
  set -euo pipefail
  cache={{quote(cache)}}
  [[ "$cache" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "Invalid cache name: $cache" >&2; exit 1; }
  token="${CACHIX_AUTH_TOKEN:-}"
  if [[ -z "$token" ]]; then
    config="${XDG_CONFIG_HOME:-$HOME/.config}/cachix/cachix.dhall"
    if [[ -f "$config" ]]; then
      token="$(sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$config" | head -n1)"
    fi
  fi
  [[ -n "$token" ]] || { echo "Cachix auth token ontbreekt" >&2; exit 1; }
  [[ "$token" =~ ^[A-Za-z0-9._~+/=-]+$ ]] || { echo "Ongeldig Cachix auth token" >&2; exit 1; }
  api() {
    printf 'header = "Authorization: Bearer %s"\n' "$token" |
      curl --config - --silent --show-error --fail-with-body "$@"
  }
  base="https://app.cachix.org/api/v1/cache/$cache"
  details="$(api "$base/details")"
  [[ "$(jq -er '.name' <<<"$details")" == "$cache" ]] || { echo "Cachix cachenaam komt niet overeen" >&2; exit 1; }
  signing_keys="$(jq -ceS '.publicSigningKeys' <<<"$details")"
  paths="$(api "$base/contents" | jq -er 'if type == "array" then length else error("expected array") end')"
  pins="$(api "$base/pin" | jq -er 'if type == "array" then length else error("expected array") end')"
  printf '%s: %s paden, %s pins\n' "$cache" "$paths" "$pins"
  if ((paths == 0 && pins == 0)); then
    echo "Cache is al leeg"
    exit 0
  fi
  [[ -t 0 ]] || { echo "Een terminal is vereist om de cache leeg te maken" >&2; exit 1; }
  printf 'Typ %s om alle inhoud en pins te verwijderen: ' "$cache" >&2
  IFS= read -r confirmation
  [[ "$confirmation" == "$cache" ]] || { echo "Niet bevestigd; niets verwijderd" >&2; exit 1; }
  api -X POST "$base/clear" >/dev/null
  remaining_pins="$(api "$base/pin" | jq -er 'if type == "array" then length else error("expected array") end')"
  if ((remaining_pins > 0)); then
    api -X POST "$base/pin/clear" >/dev/null
  fi
  paths="$(api "$base/contents" | jq -er 'if type == "array" then length else error("expected array") end')"
  pins="$(api "$base/pin" | jq -er 'if type == "array" then length else error("expected array") end')"
  details="$(api "$base/details")"
  [[ "$(jq -er '.name' <<<"$details")" == "$cache" && "$(jq -ceS '.publicSigningKeys' <<<"$details")" == "$signing_keys" ]] || {
    echo "Cache of publieke signing key is veranderd" >&2
    exit 1
  }
  ((paths == 0 && pins == 0)) || { echo "Cachix meldt nog $paths paden en $pins pins" >&2; exit 1; }
  printf 'Cache %s is leeg; configuratie en signing key zijn behouden\n' "$cache"
