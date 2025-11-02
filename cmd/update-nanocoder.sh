#!/usr/bin/env bash
# Updates pkgs/nanocoder/default.nix to the desired upstream release.

set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
  # resolve desired version from npm if none supplied
  version="$(npm view @nanocollective/nanocoder version)"
fi

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
default_nix="${repo_root}/pkgs/nanocoder/default.nix"
package_lock="${repo_root}/pkgs/nanocoder/package-lock.json"
force_empty_cache=0

case "$(uname -s)" in
  # normalize platform for npm
  Linux) npm_platform="linux" ;;
  Darwin) npm_platform="darwin" ;;
  *) npm_platform="$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
esac

case "$(uname -m)" in
  # normalize architecture for npm
  x86_64) npm_arch="x64" ;;
  aarch64|arm64) npm_arch="arm64" ;;
  *) npm_arch="$(uname -m)" ;;
esac

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

printf 'Updating nanocoder to version %s\n' "${version}"

# prefetch release tarball and record hash
prefetch_json="$(nix store prefetch-file --json --unpack "https://registry.npmjs.org/@nanocollective/nanocoder/-/nanocoder-${version}.tgz")"
source_hash="$(printf '%s' "${prefetch_json}" | jq -r '.hash')"
store_path="$(printf '%s' "${prefetch_json}" | jq -r '.storePath // .path')"

package_json_candidates=()
if [[ -f "${store_path}/package/package.json" ]]; then
  package_json_candidates+=("${store_path}/package/package.json")
fi
if [[ -f "${store_path}/package.json" ]]; then
  package_json_candidates+=("${store_path}/package.json")
fi
if [[ ${#package_json_candidates[@]} -eq 0 ]]; then
  while IFS= read -r candidate; do
    package_json_candidates+=("${candidate}")
  done < <(
    find "${store_path}" \
      -maxdepth 3 \
      -type f -name package.json \
      -not -path '*/node_modules/*' \
      2>/dev/null | sort
  )
fi
package_json_src="${package_json_candidates[0]:-}"
if [[ -z "${package_json_src}" ]]; then
  echo 'Unable to locate package.json in fetched tarball.' >&2
  exit 1
fi
package_src_dir="$(dirname "${package_json_src}")"

if [[ -f "${package_src_dir}/package-lock.json" ]]; then
  cp "${package_src_dir}/package-lock.json" "${package_lock}"
else
  # regenerate package-lock when upstream omits it
  work_dir="${tmp_dir}/package-src"
  mkdir -p "${work_dir}"
  cp -R "${package_src_dir}"/. "${work_dir}"/
  chmod -R u+w "${work_dir}"
  (
    cd "${work_dir}" && \
    npm_config_platform="${npm_platform}" \
    npm_config_arch="${npm_arch}" \
    npm_config_force=true \
    npm install --package-lock-only --ignore-scripts --no-audit --no-fund
  )
  cp "${work_dir}/package-lock.json" "${package_lock}"
fi

# determine whether npm cache will be empty
dep_count="$(jq '(.packages // {}) | keys | map(select(. != "")) | length' "${package_lock}")"
if [[ "${dep_count}" -eq 0 ]]; then
  force_empty_cache=1
fi

# bump version and source hash in default.nix
sed -i "0,/version = \".*\";/s#version = \".*\";#version = \"${version}\";#" "${default_nix}"
sed -i "0,/hash = \".*\";/s#hash = \".*\";#hash = \"${source_hash}\";#" "${default_nix}"
sed -i "0,/npmDepsHash = .*/s#npmDepsHash = .*;#npmDepsHash = lib.fakeHash;#" "${default_nix}"

if [[ "${force_empty_cache}" -eq 1 ]]; then
  if ! grep -q 'forceEmptyCache = true;' "${default_nix}"; then
    tmp_default="${tmp_dir}/default.nix"
    awk '{print $0; if ($0 ~ /npmDepsHash =/) {print ""; print "  forceEmptyCache = true;"}}' "${default_nix}" >"${tmp_default}"
    mv "${tmp_default}" "${default_nix}"
  fi
else
  sed -i '/^[[:space:]]*forceEmptyCache = true;/d' "${default_nix}"
fi

echo 'Determining npmDepsHash...'
# capture failing build log to extract new dependency hash
build_log="${tmp_dir}/build.log"
if nix build .#nanocoder --no-link >"${build_log}" 2>&1; then
  echo 'nix build unexpectedly succeeded while npmDepsHash was set to lib.fakeHash.' >&2
  cat "${build_log}" >&2
  exit 1
else
  build_status=$?
  echo "nix build exited with status ${build_status}; continuing with captured log." >&2
fi

new_npm_hash="$(grep -oE 'got:\s+sha256-[A-Za-z0-9+/=]+' "${build_log}" | awk '{print $2}' | tail -n1)"
if [[ -z "${new_npm_hash}" ]]; then
  echo 'Failed to extract npmDepsHash from nix build output.' >&2
  cat "${build_log}" >&2
  exit 1
fi

# write the real npmDepsHash and verify build
sed -i "0,/npmDepsHash = lib.fakeHash;/s#npmDepsHash = lib.fakeHash;#npmDepsHash = \"${new_npm_hash}\";#" "${default_nix}"

echo 'Verifying nix build...'
nix build .#nanocoder --no-link

echo 'nanocoder update complete.'
