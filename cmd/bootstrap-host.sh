#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: cmd/bootstrap-host.sh <hostname> [auto|laptop|workstation]

Adds the current NixOS machine to this repository. The default mode is auto:
machines with a battery become laptops, all others become workstations.

Examples:
  cmd/bootstrap-host.sh donar
  cmd/bootstrap-host.sh frigg laptop
  cmd/bootstrap-host.sh wodan workstation
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

[[ $# -ge 1 && $# -le 2 ]] || {
    usage >&2
    exit 2
}

hostname="$1"
mode="${2:-auto}"

[[ "${hostname}" =~ ^[a-z][a-z0-9-]*$ ]] ||
    die "hostname must start with a lowercase letter and contain only a-z, 0-9, or '-'"
[[ "${mode}" == "auto" || "${mode}" == "laptop" || "${mode}" == "workstation" ]] ||
    die "mode must be auto, laptop, or workstation"

command_exists nixos-generate-config ||
    die "nixos-generate-config is unavailable; run this on a NixOS installation"
command_exists nix || die "the nix command is unavailable"

script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "${script_dir}")"
hosts_index="${repo_root}/modules/hosts/default.nix"
host_module="${repo_root}/modules/hosts/${hostname}.nix"
hardware_dir="${repo_root}/hosts/${hostname}"
hardware_config="${hardware_dir}/hardware-configuration.nix"

[[ -f "${repo_root}/flake.nix" && -f "${hosts_index}" ]] ||
    die "could not find the nixcfg repository root"
[[ ! -e "${host_module}" && ! -e "${hardware_dir}" ]] ||
    die "host '${hostname}' already exists; refusing to overwrite it"

if [[ "${mode}" == "auto" ]]; then
    mode="workstation"
    for battery in /sys/class/power_supply/BAT*; do
        if [[ -e "${battery}" ]]; then
            mode="laptop"
            break
        fi
    done
fi

state_version=''
if [[ -r /etc/os-release ]]; then
    state_version="$(sed -n 's/^VERSION_ID="\{0,1\}\([^"[:space:]]*\)"\{0,1\}$/\1/p' /etc/os-release | head -n 1)"
fi
[[ "${state_version}" =~ ^[0-9]{2}\.[0-9]{2}$ ]] ||
    die "could not determine a NixOS state version from /etc/os-release"

mkdir -p -- "${hardware_dir}"
printf 'Generating hardware configuration for %s...\n' "${hostname}"
if ! nixos-generate-config --show-hardware-config >"${hardware_config}"; then
    rm -f -- "${hardware_config}"
    rmdir -- "${hardware_dir}" 2>/dev/null || true
    die "hardware configuration generation failed"
fi

if [[ "${mode}" == "laptop" ]]; then
    imports='        kde-workstation
        laptop'
else
    imports='        kde-workstation'
fi

cat >"${host_module}" <<EOF
{
  config,
  mkHost,
  ...
}: {
  flake.nixosConfigurations.${hostname} = mkHost {
    hostname = "${hostname}";
    module = {
      pkgs,
      ...
    }: {
      imports = with config.flake.modules.nixos; [
        ../../hosts/${hostname}/hardware-configuration.nix
${imports}
      ];

      boot.kernelPackages = pkgs.linuxPackages_latest;
      system.stateVersion = "${state_version}";
    };
  };
}
EOF

index_tmp="$(mktemp "${repo_root}/.bootstrap-host-index.XXXXXX")"
trap 'rm -f -- "${index_tmp}"' EXIT
awk -v new_import="    ./${hostname}.nix" '
	/^  ];$/ && !added { print new_import; added = 1 }
	{ print }
	END { if (!added) exit 1 }
' "${hosts_index}" >"${index_tmp}" || die "could not update ${hosts_index}"
mv -- "${index_tmp}" "${hosts_index}"

if command_exists alejandra; then
    alejandra "${host_module}" "${hardware_config}" "${hosts_index}" >/dev/null
fi

printf 'Evaluating nixosConfigurations.%s...\n' "${hostname}"
if ! nix --extra-experimental-features 'nix-command flakes' eval \
    "path:${repo_root}#nixosConfigurations.${hostname}.config.system.build.toplevel.drvPath" >/dev/null; then
    die "flake evaluation failed; the generated files were left in place for inspection"
fi

printf '\nHost %s was added as a %s (state version %s).\n' "${hostname}" "${mode}" "${state_version}"
printf 'Review modules/hosts/%s.nix, then activate it with:\n' "${hostname}"
printf '  sudo nixos-rebuild test --flake path:%s#%s\n' "${repo_root}" "${hostname}"
printf '  sudo nixos-rebuild switch --flake path:%s#%s\n' "${repo_root}" "${hostname}"
