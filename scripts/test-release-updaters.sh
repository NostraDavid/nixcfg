#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
export TEST_REPO="${test_root}/repo"
mkdir -p "${TEST_REPO}/scripts" "${TEST_REPO}/pkgs/acli" "${TEST_REPO}/pkgs/jpegli" "${TEST_REPO}/pkgs/semble" "${test_root}/bin"
mkdir -p "${TEST_REPO}/pkgs/"{pico-8-font,ponytail-skills,ponytail-codex}
cp "${repo_root}"/scripts/update-{acli,jpegli,semble,github-unstable,flake-package}.sh "${TEST_REPO}/scripts/"
cp "${repo_root}"/scripts/update-{pico-8-font,ponytail-skills,ponytail-codex}.sh "${TEST_REPO}/scripts/"
for package in pico-8-font ponytail-skills ponytail-codex; do
    cp "${repo_root}/pkgs/${package}/default.nix" "${TEST_REPO}/pkgs/${package}/"
done
cp "${repo_root}/flake.nix" "${TEST_REPO}/flake.nix"
cp "${repo_root}/pkgs/acli/default.nix" "${TEST_REPO}/pkgs/acli/"
cp "${repo_root}/pkgs/jpegli/default.nix" "${TEST_REPO}/pkgs/jpegli/"
cp "${repo_root}/pkgs/semble/default.nix" "${TEST_REPO}/pkgs/semble/"
export TEST_ACLI_ARCHIVE="${test_root}/acli.tar.gz"
mkdir -p "${test_root}/acli_2.0.0-stable_linux_amd64"
touch "${test_root}/acli_2.0.0-stable_linux_amd64/acli"
tar -C "${test_root}" -czf "${TEST_ACLI_ARCHIVE}" acli_2.0.0-stable_linux_amd64
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
if [[ "$*" == *acli.atlassian.com* ]]; then
    cp "${TEST_ACLI_ARCHIVE}" "${@: -1}"
else
    printf '{"tag_name":"%s"}\n' "${TEST_RELEASE:-3.3.0}"
fi
EOF
cat >"${test_root}/bin/nix" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == store ]]; then
    printf '{"hash":"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","storePath":"/test/font.ttf"}\n'
elif [[ "$1" == eval ]]; then
    printf 'https://example.invalid/pico-8.ttf'
elif [[ "$1" == hash ]]; then
    printf 'sha256-TESTHASH\n'
elif [[ "$1" == flake ]]; then
    echo 'updated input' >>"${TEST_REPO}/flake.lock"
    exit "${TEST_FLAKE_FAILURE:-0}"
else
    printf '%s\n' "$*" >>"${TEST_REPO}/builds.log"
    exit "${TEST_BUILD_FAILURE:-0}"
fi
EOF
cat >"${test_root}/bin/fc-scan" <<'EOF'
#!/usr/bin/env bash
if [[ "${TEST_INVALID_FONT:-0}" == 0 ]]; then printf 'PICO-8'; fi
EOF
chmod +x "${test_root}/bin/"*
export PATH="${test_root}/bin:${PATH}"

"${TEST_REPO}/scripts/update-acli.sh" >/dev/null
rg -q 'version = "2.0.0-stable";' "${TEST_REPO}/pkgs/acli/default.nix"
test "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/acli/default.nix")" -eq 4
rg -q '^build path:.#acli --no-link --no-write-lock-file$' "${TEST_REPO}/builds.log"

"${TEST_REPO}/scripts/update-jpegli.sh" >/dev/null
rg -q 'libjpegTurboVersion = "3.3.0";' "${TEST_REPO}/pkgs/jpegli/default.nix"
rg -q '^build .#jpegli --no-link$' "${TEST_REPO}/builds.log"
"${TEST_REPO}/scripts/update-semble.sh" >/dev/null
rg -q 'version = "0.10.0";' "${TEST_REPO}/pkgs/semble/default.nix"
# Dependency versions and hashes must remain untouched.
sed '/pname = "semble";/,$d' "${repo_root}/pkgs/semble/default.nix" >"${test_root}/before"
sed '/pname = "semble";/,$d' "${TEST_REPO}/pkgs/semble/default.nix" >"${test_root}/after"
cmp "${test_root}/before" "${test_root}/after"

export TEST_BUILD_FAILURE=1
cp "${repo_root}/pkgs/acli/default.nix" "${TEST_REPO}/pkgs/acli/default.nix"
if "${TEST_REPO}/scripts/update-acli.sh" >/dev/null 2>&1; then
    echo 'Expected acli build failure' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/acli/default.nix" "${TEST_REPO}/pkgs/acli/default.nix"
for package in jpegli semble; do
    cp "${repo_root}/pkgs/${package}/default.nix" "${TEST_REPO}/pkgs/${package}/default.nix"
    if "${TEST_REPO}/scripts/update-${package}.sh" >/dev/null 2>&1; then
        echo "Expected ${package} build failure" >&2
        exit 1
    fi
    cmp "${repo_root}/pkgs/${package}/default.nix" "${TEST_REPO}/pkgs/${package}/default.nix"
done
export TEST_RELEASE=3.4.0-beta1
if "${TEST_REPO}/scripts/update-jpegli.sh" >/dev/null 2>&1; then
    echo 'Expected invalid release tag to fail' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/jpegli/default.nix" "${TEST_REPO}/pkgs/jpegli/default.nix"

# Failed input updates and builds must preserve pre-existing lockfile changes.
printf 'existing user changes\n' >"${TEST_REPO}/flake.lock"
cp "${TEST_REPO}/flake.lock" "${test_root}/flake.lock.before"
if bash "${TEST_REPO}/scripts/update-flake-package.sh" skills skills >/dev/null 2>&1; then
    echo 'Expected flake package build failure' >&2
    exit 1
fi
cmp "${test_root}/flake.lock.before" "${TEST_REPO}/flake.lock"
export TEST_BUILD_FAILURE=0 TEST_FLAKE_FAILURE=1
if bash "${TEST_REPO}/scripts/update-flake-package.sh" skills skills >/dev/null 2>&1; then
    echo 'Expected flake update failure' >&2
    exit 1
fi
cmp "${test_root}/flake.lock.before" "${TEST_REPO}/flake.lock"
export TEST_FLAKE_FAILURE=0
bash "${TEST_REPO}/scripts/update-flake-package.sh" skills skills >/dev/null
rg -q '^updated input$' "${TEST_REPO}/flake.lock"

"${TEST_REPO}/scripts/update-pico-8-font.sh" >/dev/null
rg -q 'hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";' "${TEST_REPO}/pkgs/pico-8-font/default.nix"
rg -q '^build .#pico-8-font --no-link$' "${TEST_REPO}/builds.log"
for failure in build font; do
    cp "${repo_root}/pkgs/pico-8-font/default.nix" "${TEST_REPO}/pkgs/pico-8-font/default.nix"
    export TEST_BUILD_FAILURE=0 TEST_INVALID_FONT=0
    if [[ "${failure}" == build ]]; then TEST_BUILD_FAILURE=1; else TEST_INVALID_FONT=1; fi
    if "${TEST_REPO}/scripts/update-pico-8-font.sh" >/dev/null 2>&1; then
        echo "Expected font updater ${failure} failure" >&2
        exit 1
    fi
    cmp "${repo_root}/pkgs/pico-8-font/default.nix" "${TEST_REPO}/pkgs/pico-8-font/default.nix"
done
export TEST_BUILD_FAILURE=0 TEST_INVALID_FONT=0
"${TEST_REPO}/scripts/update-ponytail-codex.sh" >/dev/null
for package in ponytail-skills ponytail-codex; do
    rg -q 'version = "0.10.0";' "${TEST_REPO}/pkgs/${package}/default.nix"
    rg -q "^build .#${package} --no-link$" "${TEST_REPO}/builds.log"
done
echo 'Release updater regression checks passed.'
