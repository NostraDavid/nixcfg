#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
cd "${repo_root}"

system="${NIX_SYSTEM:-$(nix eval --impure --raw --expr 'builtins.currentSystem')}"
flake_packages=".#packages.${system}"
export NIX_CONFIG=$'warn-dirty = false\n'"${NIX_CONFIG:-}"

usage() {
	cat <<'EOF'
Usage:
  cmd/local-package-maint.sh update <package>
  cmd/local-package-maint.sh list [package...]
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

package_exists() {
	local dir="$1"
	local pkg="$2"

	pkg_eval_raw "${dir}" "${pkg}" "pkgs.\"${pkg}\".pname" >/dev/null 2>&1
}

package_version() {
	local dir="$1"
	local pkg="$2"

	pkg_eval_raw "${dir}" "${pkg}" "pkgs.\"${pkg}\".version"
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

list_packages() {
	(
		cd "${repo_root}"
		nix eval --json "${flake_packages}" --apply 'pkgs: builtins.attrNames pkgs' | jq -r '.[]'
	)
}

local_update_script() {
	local dir="$1"
	local pkg="$2"
	local script="${dir}/cmd/update-${pkg}.sh"

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
	local -a cmd

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
		"${cmd[@]}" -F "${pkg}"
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
		printf 'Unsupported updater for %s\n' "${pkg}" >&2
		return 2
		;;
	*)
		printf 'Unknown updater mode for %s: %s\n' "${pkg}" "${mode}" >&2
		return 1
		;;
	esac
}

probe_skip_reason() {
	local dir="$1"
	local pkg="$2"
	local current_version
	local mode

	current_version="$(package_version "${dir}" "${pkg}")"
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

ensure_package() {
	local dir="$1"
	local pkg="$2"

	if package_exists "${dir}" "${pkg}"; then
		return 0
	fi

	printf 'Unknown local package: %s\n' "${pkg}" >&2
	printf 'Available packages:\n' >&2
	list_packages | sed 's/^/  /' >&2
	exit 1
}

list_updates() {
	local packages=("$@")

	if [[ ${#packages[@]} -eq 0 ]]; then
		mapfile -t packages < <(list_packages)
	fi

	local found=0
	local pkg before after tmpdir update_log
	local skip_reason
	local -a skipped=()

	for pkg in "${packages[@]}"; do
		ensure_package "${repo_root}" "${pkg}"
		before="$(package_version "${repo_root}" "${pkg}")"

		if skip_reason="$(probe_skip_reason "${repo_root}" "${pkg}")"; then
			skipped+=("${pkg}: ${skip_reason}")
			continue
		fi

		tmpdir="$(mktemp -d)"
		update_log="${tmpdir}/update.log"
		mkdir -p "${tmpdir}/repo"

		cp -a "${repo_root}/." "${tmpdir}/repo"

		if run_update "${tmpdir}/repo" "${pkg}" >"${update_log}" 2>&1; then
			after="$(package_version "${tmpdir}/repo" "${pkg}")"
			if [[ "${before}" != "${after}" ]] && looks_like_real_version "${after}"; then
				printf '%s %s -> %s\n' "${pkg}" "${before}" "${after}"
				found=1
			fi
		else
			skip_reason="$(summarize_failure "${update_log}")"
			skipped+=("${pkg}: ${skip_reason}")
		fi

		rm -rf "${tmpdir}"
	done

	if [[ "${found}" -eq 0 ]]; then
		echo "No newer versions found."
	fi

	if [[ ${#skipped[@]} -gt 0 ]]; then
		printf 'Skipped probes:\n' >&2
		printf '  %s\n' "${skipped[@]}" >&2
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
		if [[ $# -ne 1 ]]; then
			usage >&2
			exit 1
		fi
		ensure_package "${repo_root}" "$1"
		if skip_reason="$(probe_skip_reason "${repo_root}" "$1")"; then
			printf 'Skipping update for %s: %s\n' "$1" "${skip_reason}"
			exit 0
		fi
		run_update "${repo_root}" "$1"
		;;
	list)
		list_updates "$@"
		;;
	*)
		usage >&2
		exit 1
		;;
	esac
}

main "$@"
