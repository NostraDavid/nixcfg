#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

# shellcheck source=scripts/github-auth.sh
source "${repo_root}/scripts/github-auth.sh"

system="${NIX_SYSTEM:-$(nix eval --impure --raw --expr 'builtins.currentSystem')}"
flake_packages=".#packages.${system}"
export NIX_CONFIG=$'warn-dirty = false\n'"${NIX_CONFIG:-}"

if [[ -t 1 || -t 2 ]]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_BOLD=$'\033[1m'
else
    C_RESET=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_BOLD=''
fi

print_info() {
    printf '%s%s%s\n' "${C_BLUE}" "$1" "${C_RESET}"
}

print_success() {
    printf '%s%s%s\n' "${C_GREEN}" "$1" "${C_RESET}"
}

print_warning() {
    printf '%s%s%s\n' "${C_YELLOW}" "$1" "${C_RESET}"
}

print_error() {
    printf '%s%s%s\n' "${C_RED}" "$1" "${C_RESET}" >&2
}

print_log_line() {
    local line="$1"
    local stream="${2:-stdout}"
    local prefix='' suffix=''

    case "${line}" in
    Updating\ *to\ version* | Updating\ *to\ unstable-*)
        prefix="${C_BOLD}${C_BLUE}"
        suffix="${C_RESET}"
        ;;
    Verifying\ nix\ build... | Determining\ source\ hash... | No\ changes\ detected,*)
        prefix="${C_BLUE}"
        suffix="${C_RESET}"
        ;;
    *update\ complete.)
        prefix="${C_GREEN}"
        suffix="${C_RESET}"
        ;;
    Skipping\ update\ for*)
        prefix="${C_YELLOW}"
        suffix="${C_RESET}"
        ;;
    *error:* | error:* | *Error:* | Traceback* | *failed* | *Failed*)
        prefix="${C_RED}"
        suffix="${C_RESET}"
        ;;
    esac

    if [[ "${stream}" == "stderr" ]]; then
        printf '%s%s%s\n' "${prefix}" "${line}" "${suffix}" >&2
    else
        printf '%s%s%s\n' "${prefix}" "${line}" "${suffix}"
    fi
}

emit_log_file() {
    local log_file="$1"
    local stream="${2:-stdout}"
    local line

    while IFS= read -r line || [[ -n "${line}" ]]; do
        print_log_line "${line}" "${stream}"
    done <"${log_file}"
}

usage() {
    cat <<'EOF'
Usage:
  scripts/local-package-maint.sh update <package>
  scripts/local-package-maint.sh list [package...]
  scripts/local-package-maint.sh packages
  scripts/local-package-maint.sh cache-targets
EOF
}

pkg_eval_raw() {
    local dir="$1"
    local pkg="$2"
    local expr="$3"

    (
        cd "${dir}"
        nix eval --raw "${flake_packages}" --apply "pkgs: ${expr}"
    )
}

pkg_eval_json() {
    local dir="$1"
    local pkg="$2"
    local expr="$3"

    (
        cd "${dir}"
        nix eval --json "${flake_packages}" --apply "pkgs: ${expr}"
    )
}

package_metadata() {
    local dir="$1"
    local pkg="$2"
    local has_recipe=false metadata
    if [[ -f "$dir/pkgs/$pkg/default.nix" ]]; then has_recipe=true; fi
    metadata="$(pkg_eval_json "$dir" "$pkg" "
      if !(builtins.hasAttr \"$pkg\" pkgs) then null else let
        package = pkgs.\"$pkg\";
        reason = if $has_recipe then package.passthru.updateSkipReason or \"\"
          else \"generated flake output; updated through flake inputs and configuration\";
      in { inherit reason; version = if reason == \"\" then package.version or \"\" else \"\"; }
    ")" || return 1
    if [[ $metadata == null ]]; then
        print_error "Unknown local package: $pkg"
        printf '%sAvailable packages:%s\n' "${C_BOLD}" "${C_RESET}" >&2
        list_packages | sed 's/^/  /' >&2
        return 1
    fi
    printf '%s\n' "$metadata"
}

package_version() {
    local dir="$1"
    local pkg="$2"

    pkg_eval_raw "${dir}" "${pkg}" "pkgs.\"${pkg}\".version or \"\""
}

package_has_update_script() {
    local dir="$1"
    local pkg="$2"

    pkg_eval_json "${dir}" "${pkg}" "pkgs.\"${pkg}\".passthru ? updateScript" | jq -er . >/dev/null
}

package_update_script() {
    local dir="$1"
    local pkg="$2"

    pkg_eval_json "${dir}" "${pkg}" "if pkgs.\"${pkg}\".passthru ? updateScript then toString pkgs.\"${pkg}\".passthru.updateScript else null" | jq -r '. // empty'
}

filter_bulk_packages() {
    if [[ ${NIXCFG_BULK_HOST:-} != wodan ]]; then
        cat
        return
    fi
    local package
    while IFS= read -r package; do
        case "$package" in
        *-image | proxmox-lab | headlamp-identity | paperclip) continue ;;
        esac
        printf '%s\n' "$package"
    done
}

list_packages() {
    (
        cd "${repo_root}"
        nix eval --json "${flake_packages}" --apply 'pkgs: builtins.filter (name:
          (pkgs.${name}.passthru.updateSkipReason or "") == ""
        ) (builtins.attrNames pkgs)' | jq -r '.[]' | filter_bulk_packages | while IFS= read -r pkg; do
            if [[ -f "${repo_root}/pkgs/${pkg}/default.nix" ]]; then
                printf '%s\n' "${pkg}"
            fi
        done
    )
}

local_update_script() {
    local dir="$1"
    local pkg="$2"
    local script="${dir}/scripts/update-${pkg}.sh"

    if [[ -f "${script}" ]]; then
        printf '%s\n' "${script}"
        return 0
    fi

    return 1
}

version_supported_for_generic_probe() {
    local version="$1"

    if [[ "${version}" =~ (^|-)unstable- ]]; then
        return 1
    fi

    if [[ "${version}" =~ (^|[.-])(alpha|beta|rc|pre)([.-]|[0-9]|$) ]]; then
        return 1
    fi

    return 0
}

looks_like_real_version() {
    local version="$1"

    [[ "${version}" =~ [0-9] ]]
}

run_embedded_nix_update() {
    local dir="$1"
    local pkg="$2"
    local update_script
    local -a cmd extra_args

    update_script="$(package_update_script "${dir}" "${pkg}")"
    read -r -a cmd <<<"${update_script}"

    if [[ ${#cmd[@]} -eq 0 ]]; then
        return 1
    fi

    if [[ "$(basename "${cmd[0]}")" != "nix-update" ]]; then
        return 1
    fi

    (
        cd "${dir}"
        extra_args=("${cmd[@]:1}")
        nix run nixpkgs#nix-update -- "${extra_args[@]}" -F "${pkg}"
    )
}

update_mode() {
    local dir="$1"
    local pkg="$2"
    local update_script
    local first_word

    if local_update_script "${dir}" "${pkg}" >/dev/null; then
        echo "local-script"
        return 0
    fi

    if ! package_has_update_script "${dir}" "${pkg}"; then
        echo "generic"
        return 0
    fi

    update_script="$(package_update_script "${dir}" "${pkg}")"
    first_word="${update_script%% *}"

    if [[ "$(basename "${first_word}")" == "nix-update" ]]; then
        echo "embedded-nix-update"
        return 0
    fi

    echo "unsupported-external-script"
}

run_update() {
    local dir="$1"
    local pkg="$2"
    local local_script
    local mode

    mode="$(update_mode "${dir}" "${pkg}")"

    case "${mode}" in
    local-script)
        local_script="$(local_update_script "${dir}" "${pkg}")"
        (
            cd "${dir}"
            bash "${local_script}"
        )
        ;;
    embedded-nix-update)
        run_embedded_nix_update "${dir}" "${pkg}"
        ;;
    generic)
        (
            cd "${dir}"
            nix run nixpkgs#nix-update -- -F "${pkg}"
        )
        ;;
    unsupported-external-script)
        print_error "Unsupported updater for ${pkg}"
        return 2
        ;;
    *)
        print_error "Unknown updater mode for ${pkg}: ${mode}"
        return 1
        ;;
    esac
}

probe_skip_reason() {
    local dir="$1"
    local pkg="$2"
    local metadata="$3"
    local current_version
    local mode
    local reason

    reason="$(jq -r .reason <<<"$metadata")"
    if [[ -n "${reason}" ]]; then
        printf '%s\n' "${reason}"
        return 0
    fi

    current_version="$(jq -r .version <<<"$metadata")"
    if [[ -z "${current_version}" ]]; then
        echo "no package version (may be managed by a flake input)"
        return 0
    fi

    mode="$(update_mode "${dir}" "${pkg}")"

    if [[ "${mode}" == "unsupported-external-script" ]]; then
        echo "inherited external updater"
        return 0
    fi

    if [[ "${mode}" == "generic" ]] && ! version_supported_for_generic_probe "${current_version}"; then
        echo "unsupported current version scheme (${current_version})"
        return 0
    fi

    return 1
}

summarize_failure() {
    local log_file="$1"

    if rg -q 'Please specify the version' "${log_file}"; then
        echo "upstream version discovery not supported"
        return 0
    fi

    if rg -q 'Found an unstable version' "${log_file}"; then
        echo "upstream only exposes unstable or prerelease versions"
        return 0
    fi

    if rg -q 'No version matched the regex' "${log_file}"; then
        echo "no stable upstream release matched the updater regex"
        return 0
    fi

    if rg -q 'Updating .* to version null' "${log_file}"; then
        echo "upstream release API returned no version"
        return 0
    fi

    if rg -q 'trying https://.*VV[0-9]' "${log_file}"; then
        echo "automatic probe needs a custom version regex"
        return 0
    fi

    if rg -q 'Failed to extract hash from nix build output|requested URL returned error: 404' "${log_file}"; then
        echo "package-specific update script uses an outdated asset URL"
        return 0
    fi

    if rg -q 'husky: command not found|npm error code 127' "${log_file}"; then
        echo "package-specific update script failed"
        return 0
    fi

    if rg -q 'Unsupported updater for' "${log_file}"; then
        sed -n '$p' "${log_file}"
        return 0
    fi

    echo "update probe failed"
    return 0
}

list_updates() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        mapfile -t packages < <(list_packages)
    fi

    local found=0
    local pkg before after tmpdir update_log updater metadata
    local skip_reason
    local -a skipped=()
    local -a failed=()

    for pkg in "${packages[@]}"; do
        metadata="$(package_metadata "${repo_root}" "${pkg}")"
        if skip_reason="$(probe_skip_reason "${repo_root}" "${pkg}" "$metadata")"; then
            skipped+=("${pkg}: ${skip_reason}")
            continue
        fi

        before="$(jq -r .version <<<"$metadata")"
        updater="${repo_root}/scripts/update-${pkg}.sh"
        if [[ "$updater" -ef "${repo_root}/scripts/update-prebuilt-github.sh" ]]; then
            if ! after="$(bash "$updater" --latest-version)"; then
                failed+=("${pkg}: release tag lookup failed")
            elif [[ "$after" != "$before" && "$(printf '%s\n' "$before" "$after" | sort -V | tail -n1)" == "$after" ]]; then
                print_success "${pkg} ${before} -> ${after}"
                found=1
            fi
            continue
        fi

        tmpdir="$(mktemp -d)"
        update_log="${tmpdir}/update.log"
        mkdir -p "${tmpdir}/repo"

        cp -a "${repo_root}/." "${tmpdir}/repo"

        if run_update "${tmpdir}/repo" "${pkg}" >"${update_log}" 2>&1; then
            after="$(package_version "${tmpdir}/repo" "${pkg}")"
            if [[ "${before}" != "${after}" ]] && looks_like_real_version "${after}"; then
                print_success "${pkg} ${before} -> ${after}"
                found=1
            elif ! cmp -s "${repo_root}/flake.lock" "${tmpdir}/repo/flake.lock"; then
                print_success "${pkg} ${before} (flake input updated)"
                found=1
            fi
        else
            skip_reason="$(summarize_failure "${update_log}")"
            failed+=("${pkg}: ${skip_reason}")
            emit_log_file "${update_log}" stderr
        fi

        rm -rf "${tmpdir}"
    done

    if [[ "${found}" -eq 0 && ${#failed[@]} -eq 0 ]]; then
        print_info "No newer versions found."
    fi

    if [[ ${#skipped[@]} -gt 0 ]]; then
        printf '%sSkipped probes:%s\n' "${C_BOLD}${C_YELLOW}" "${C_RESET}" >&2
        printf '  %s\n' "${skipped[@]}" >&2
    fi

    if [[ ${#failed[@]} -gt 0 ]]; then
        print_error 'Failed probes:'
        printf '  %s\n' "${failed[@]}" >&2
        return 1
    fi
}

main() {
    if [[ $# -lt 1 ]]; then
        usage >&2
        exit 1
    fi

    local command="$1"
    shift

    case "${command}" in
    update)
        local tmpdir update_log skip_reason status attempt metadata
        if [[ $# -ne 1 ]]; then
            usage >&2
            exit 1
        fi
        metadata="$(package_metadata "${repo_root}" "$1")"
        if skip_reason="$(probe_skip_reason "${repo_root}" "$1" "$metadata")"; then
            print_warning "Skipping update for $1: ${skip_reason}"
            exit 0
        fi
        if [[ ${NIXCFG_SKIP_UNCHANGED:-0} == 1 ]]; then
            export NIXCFG_CURRENT_VERSION
            NIXCFG_CURRENT_VERSION="$(jq -r .version <<<"$metadata")"
        fi
        tmpdir="$(mktemp -d)"
        update_log="${tmpdir}/update.log"
        for attempt in 1 2 3; do
            if run_update "${repo_root}" "$1" >"${update_log}" 2>&1; then
                emit_log_file "${update_log}"
                rm -rf "${tmpdir}"
                exit 0
            else
                status=$?
            fi
            if [[ "${attempt}" -eq 3 ]] || ! rg -q 'HTTP( Error)?[ :]+(429|5[0-9]{2})|requested URL returned error: (429|5[0-9]{2})' "${update_log}"; then
                break
            fi
            emit_log_file "${update_log}" stderr
            print_warning "Temporary HTTP failure updating $1; retrying (attempt $((attempt + 1))/3)."
            sleep "${attempt}"
        done
        print_error "Update failed for $1: $(summarize_failure "${update_log}")"
        emit_log_file "${update_log}" stderr
        rm -rf "${tmpdir}"
        exit "${status}"
        ;;
    list)
        list_updates "$@"
        ;;
    packages)
        list_packages
        ;;
    cache-targets)
        # Wodan builds its own eSpeak variant without the full MBROLA voice bundle.
        nix eval --json "$flake_packages" --apply builtins.attrNames | jq -r '.[]' | filter_bulk_packages |
            awk -v host="${NIXCFG_BULK_HOST:-}" '{
                if (host == "wodan" && $0 == "espeak-ng") print ".#nixosConfigurations.wodan.pkgs.espeak-ng"
                else print ".#" $0
            }'
        ;;
    *)
        usage >&2
        exit 1
        ;;
    esac
}

main "$@"
