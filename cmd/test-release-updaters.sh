#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
export TEST_REPO="${test_root}/repo"
mkdir -p "${TEST_REPO}/cmd" "${TEST_REPO}/pkgs/jpegli" "${TEST_REPO}/pkgs/semble" "${test_root}/bin"
cp "${repo_root}"/cmd/update-{jpegli,semble,github-unstable}.sh "${TEST_REPO}/cmd/"
cp "${repo_root}/pkgs/jpegli/default.nix" "${TEST_REPO}/pkgs/jpegli/"
cp "${repo_root}/pkgs/semble/default.nix" "${TEST_REPO}/pkgs/semble/"
export TEST_MAIN_REV
TEST_MAIN_REV="$(sed -n '/repo = "jpegli"/,/};/s/.*rev = "\([^"]*\)";/\1/p' "${TEST_REPO}/pkgs/jpegli/default.nix")"

cat >"${test_root}/bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == -C ]]; then
    printf '%s\n' "${TEST_REPO}"
elif [[ "${*: -1}" == HEAD ]]; then
    printf '%s\tHEAD\n' "${TEST_MAIN_REV}"
else
    printf 'abc\trefs/tags/v0.9.0\nabc\trefs/tags/v0.10.0\nabc\trefs/tags/v1.0.0-rc1\n'
fi
EOF
cat >"${test_root}/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '{"tag_name":"%s"}\n' "${TEST_RELEASE:-3.3.0}"
EOF
cat >"${test_root}/bin/nix" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == store ]]; then
    printf '{"hash":"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="}\n'
else
    printf '%s\n' "$*" >>"${TEST_REPO}/builds.log"
    exit "${TEST_BUILD_FAILURE:-0}"
fi
EOF
chmod +x "${test_root}/bin/"*
export PATH="${test_root}/bin:${PATH}"

"${TEST_REPO}/cmd/update-jpegli.sh" >/dev/null
rg -q 'libjpegTurboVersion = "3.3.0";' "${TEST_REPO}/pkgs/jpegli/default.nix"
rg -q '^build .#jpegli --no-link$' "${TEST_REPO}/builds.log"
"${TEST_REPO}/cmd/update-semble.sh" >/dev/null
rg -q 'version = "0.10.0";' "${TEST_REPO}/pkgs/semble/default.nix"
# Dependency versions and hashes must remain untouched.
sed '/pname = "semble";/,$d' "${repo_root}/pkgs/semble/default.nix" >"${test_root}/before"
sed '/pname = "semble";/,$d' "${TEST_REPO}/pkgs/semble/default.nix" >"${test_root}/after"
cmp "${test_root}/before" "${test_root}/after"

export TEST_BUILD_FAILURE=1
for package in jpegli semble; do
    cp "${repo_root}/pkgs/${package}/default.nix" "${TEST_REPO}/pkgs/${package}/default.nix"
    if "${TEST_REPO}/cmd/update-${package}.sh" >/dev/null 2>&1; then
        echo "Expected ${package} build failure" >&2
        exit 1
    fi
    cmp "${repo_root}/pkgs/${package}/default.nix" "${TEST_REPO}/pkgs/${package}/default.nix"
done
export TEST_RELEASE=3.4.0-beta1
if "${TEST_REPO}/cmd/update-jpegli.sh" >/dev/null 2>&1; then
    echo 'Expected invalid release tag to fail' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/jpegli/default.nix" "${TEST_REPO}/pkgs/jpegli/default.nix"
echo 'Release updater regression checks passed.'
