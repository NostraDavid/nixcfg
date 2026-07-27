#!/usr/bin/env bash
set -euo pipefail

archive_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
sources_root="$(dirname -- "$archive_root")/skill-sources"

declare -A revisions=(
    ["awesome-copilot"]="822a551eaf80f6a8e9de8bb19d02f0d0b60ae842"
    ["codex-system"]="codex-cli-0.144.3_2575ff8690bf93c7"
    ["matt-pocock"]="v1.1.0"
    ["polars-inc"]="v0.2.0"
)

compare_skill() {
    local group="$1"
    local skill="$2"
    local revision="${revisions[$group]:-}"
    local original="$archive_root/$group/$revision/skills/$skill"
    local variant="$sources_root/$group/$skill"

    if [[ -z "$revision" || ! -d "$original" || ! -d "$variant" ]]; then
        printf 'Unknown archived skill: %s/%s\n' "$group" "$skill" >&2
        return 2
    fi

    diff -ru "$original" "$variant"
}

summarize() {
    local group revision original skill variant report
    local changed original_only variant_only total

    printf '%-18s %-36s %8s %8s %8s %8s\n' \
        group skill total changed original variant

    for group in awesome-copilot codex-system matt-pocock polars-inc; do
        revision="${revisions[$group]}"
        for original in "$archive_root/$group/$revision/skills"/*; do
            [[ -d "$original" ]] || continue
            skill="${original##*/}"
            variant="$sources_root/$group/$skill"
            report="$(diff -qr "$original" "$variant" || true)"
            changed="$(grep -c '^Files ' <<<"$report" || true)"
            original_only="$(grep -c "^Only in $original" <<<"$report" || true)"
            variant_only="$(grep -c "^Only in $variant" <<<"$report" || true)"
            total="$(sed '/^$/d' <<<"$report" | wc -l)"
            printf '%-18s %-36s %8d %8d %8d %8d\n' \
                "$group" "$skill" "$total" "$changed" "$original_only" "$variant_only"
        done
    done
}

case "$#" in
0)
    summarize
    ;;
2)
    compare_skill "$1" "$2"
    ;;
*)
    printf 'Usage: %s [GROUP SKILL]\n' "${0##*/}" >&2
    exit 2
    ;;
esac
