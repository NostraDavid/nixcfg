#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 || ! "$1" =~ ^(vex|report)$ || ! "$2" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    echo 'Usage: security-report.sh <vex|report> <host> <output-directory>' >&2
    exit 1
fi
mode="$1"
host="$2"
repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
# shellcheck source=scripts/github-auth.sh
source "${repo_root}/scripts/github-auth.sh"

mkdir -p "$3/$host"
report_dir="$(mktemp -d "$3/$host/run.XXXXXXXX")"
report_dir="$(realpath "$report_dir")"
manifest="$report_dir/manifest.json"
failed=0
grype_db_dir=''
jq -n --arg host "$host" --arg mode "$mode" --arg started_at "$(date -u +%FT%TZ)" \
    '{host: $host, mode: $mode, started_at: $started_at, advisory_only: true, steps: {}}' >"$manifest"
printf 'Security report: %s\n' "$report_dir"

update_manifest() {
    jq "$@" "$manifest" >"$manifest.tmp" && mv "$manifest.tmp" "$manifest"
}

finish() {
    local status=$?
    trap - EXIT
    update_manifest --argjson status "$status" --arg finished_at "$(date -u +%FT%TZ)" \
        '.exit_status = $status | .finished_at = $finished_at' || status=1
    if [[ -n "$grype_db_dir" ]]; then rm -rf "$grype_db_dir"; fi
    exit "$status"
}
trap finish EXIT

# Keep tool exit codes and stderr even when another scanner reports findings.
run_step() {
    local name="$1" output="$2" status=0
    shift 2
    printf 'Running %s\n' "$name"
    "$@" >"$report_dir/$output" 2>"$report_dir/$name.stderr.log" || status=$?
    update_manifest --arg name "$name" --arg output "$output" --argjson status "$status" \
        '.steps[$name] = {exit_status: $status, output: $output, stderr: ($name + ".stderr.log")}' || {
        failed=1
        return 1
    }
    if [[ "$status" -ne 0 ]]; then
        failed=1
        printf '%s exited with %s; see %s\n' "$name" "$status" "$report_dir/$name.stderr.log" >&2
    fi
    return "$status"
}

validate_json() {
    run_step "validate-$1" "$1.validation.log" jq -e "$3" "$report_dir/$2"
}

run_step snapshot snapshot.json nix flake archive --json --no-update-lock-file --no-write-lock-file "$repo_root" || exit 1
snapshot="$(jq -er '.path | select(startswith("/"))' "$report_dir/snapshot.json")"
upstream_revision="$(jq -er '.nodes[.nodes.root.inputs["nixos-vex"]].locked.rev' "$snapshot/flake.lock")"
flake="path:$snapshot"
config_ref="$flake#nixosConfigurations.\"$host\".config"
update_manifest --arg snapshot "$snapshot" --arg revision "$upstream_revision" \
    '.source_snapshot = $snapshot | .upstream_revision = $revision'

run_step supported-host supported-host.json nix eval --json "$flake#nixosConfigurations" \
    --apply "hosts: builtins.hasAttr \"$host\" hosts && (hosts.\"$host\".config.system.build ? vexFeed)" || exit 1
if ! jq -e '. == true' "$report_dir/supported-host.json" >/dev/null; then
    echo "Host '$host' does not export system.build.vexFeed; the VEX pilot is enabled for Wodan only." >&2
    exit 1
fi

run_step vex vex.path nix build --no-link --no-write-lock-file --no-update-lock-file \
    --print-out-paths "$config_ref.system.build.vexFeed" || exit 1
cp "$(cat "$report_dir/vex.path")" "$report_dir/vex.openvex.json"
validate_json vex vex.openvex.json \
    'type == "object" and ."@context" == "https://openvex.dev/ns/v0.2.0" and (.author | type) == "string" and (.statements | type) == "array"' || exit 1
run_step dropped-conditions vex.dropped.json nix eval --json "$config_ref.nixosVex.dropped" || exit 1
validate_json dropped-conditions vex.dropped.json 'type == "object" and all(.[]; type == "array")' || exit 1
run_step conditions vex.conditions.json nix eval --json "$config_ref.nixosVex.conditions" || exit 1
validate_json conditions vex.conditions.json 'type == "object" and all(.[]; type == "boolean")' || exit 1
if [[ "$mode" == vex ]]; then exit 0; fi

run_step system system.path nix build --no-link --no-write-lock-file --no-update-lock-file \
    --print-out-paths "$config_ref.system.build.toplevel" || exit 1
system_path="$(cat "$report_dir/system.path")"
update_manifest --arg system_path "$system_path" '.system_path = $system_path'

for tool in nix sbomnix grype osv-scanner vulnix; do
    if [[ "$tool" == grype ]]; then version_flag=version; else version_flag=--version; fi
    run_step "$tool-version" "$tool.version.txt" "$tool" "$version_flag" || true
    update_manifest --arg tool "$tool" --rawfile version "$report_dir/$tool.version.txt" \
        '.scanner_versions[$tool] = ($version | rtrimstr("\n"))'
done

run_step sbom sbomnix.stdout.log sbomnix "$config_ref.system.build.toplevel" \
    --csv "$report_dir/sbom.csv" --cdx "$report_dir/sbom.cdx.json" --spdx "$report_dir/sbom.spdx.json" || exit 1
validate_json cyclonedx sbom.cdx.json '.bomFormat == "CycloneDX" and (.components | type) == "array"' || exit 1
validate_json spdx sbom.spdx.json '(.spdxVersion | startswith("SPDX-")) and (.packages | type) == "array"' || exit 1
run_step csv csv.validation.log test -s "$report_dir/sbom.csv" || exit 1

# A private database and controlled configuration keep both scans comparable.
# Never inherit local VEX documents, ignore rules, or severity filters.
grype_db_dir="$(mktemp -d)"
printf '{}\n' >"$report_dir/grype.yaml"
grype_scan() (
    while IFS= read -r variable; do unset "$variable"; done < <(compgen -v GRYPE_)
    export GRYPE_DB_CACHE_DIR="$grype_db_dir"
    export GRYPE_DB_AUTO_UPDATE=false
    export GRYPE_CHECK_FOR_APP_UPDATE=false
    grype --config "$report_dir/grype.yaml" "$@"
)

if run_step grype-db-update grype-db-update.log grype_scan db update &&
    run_step grype-db-status grype-db.json grype_scan db status -o json &&
    validate_json grype-db grype-db.json '.valid == true'; then
    run_step grype-raw grype.raw.json grype_scan "sbom:$report_dir/sbom.cdx.json" --fail-on critical -o json || true
    validate_json grype-raw grype.raw.json \
        '.descriptor.name == "grype" and (.matches | type) == "array" and ((.ignoredMatches // []) | type) == "array"' || true
    run_step grype-advisory grype.advisory.json grype_scan "sbom:$report_dir/sbom.cdx.json" \
        --vex "$report_dir/vex.openvex.json" -o json || true
    validate_json grype-advisory grype.advisory.json \
        '.descriptor.name == "grype" and (.matches | type) == "array" and ((.ignoredMatches // []) | type) == "array"' || true
    run_step grype-db-unchanged grype-db-after.json grype_scan db status -o json || true
    run_step compare-grype-db grype-db.validation.log cmp "$report_dir/grype-db.json" "$report_dir/grype-db-after.json" || true
fi

run_step osv osv.json osv-scanner scan source -L "$report_dir/sbom.cdx.json" --format json || true
validate_json osv osv.json 'type == "object" and (.results | type) == "array"' || true
run_step vulnix vulnix.json vulnix --json "$system_path" || true
validate_json vulnix vulnix.json 'type == "array"' || true

printf 'Reports retained in %s\n' "$report_dir"
exit "$failed"
