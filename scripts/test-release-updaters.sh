#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$(dirname "$0")"/.. rev-parse --show-toplevel)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT
export TEST_REPO="${test_root}/repo"
mkdir -p "${TEST_REPO}/pkgs/"{opencode-v2,opencode-v2-desktop} "${TEST_REPO}/scripts"
cp "${repo_root}/scripts/update-opencode-v2.sh" "${TEST_REPO}/scripts/"
ln -s update-opencode-v2.sh "${TEST_REPO}/scripts/update-opencode-v2-desktop.sh"
for package in opencode-v2 opencode-v2-desktop; do
    cp "${repo_root}/pkgs/${package}/default.nix" "${TEST_REPO}/pkgs/${package}/"
done
mkdir -p "${TEST_REPO}/scripts" "${TEST_REPO}/pkgs/acli" "${TEST_REPO}/pkgs/jpegli" "${TEST_REPO}/pkgs/semble" "${test_root}/bin"
mkdir -p "${TEST_REPO}/pkgs/"{pico-8-font,ponytail-skills,ponytail-codex}
mkdir -p "${TEST_REPO}/pkgs/cmux-tui"
cp "${repo_root}/pkgs/cmux-tui/default.nix" "${TEST_REPO}/pkgs/cmux-tui/"
cp "${repo_root}/scripts/update-cmux-tui.sh" "${repo_root}/scripts/update-databricks-agent-skills.sh" "${TEST_REPO}/scripts/"
mkdir -p "${TEST_REPO}/pkgs/codex"
cp "${repo_root}/scripts/update-prebuilt-github.sh" "${TEST_REPO}/scripts/"
mkdir -p "${TEST_REPO}/pkgs/orca-ide"
cp "${repo_root}/pkgs/orca-ide/default.nix" "${TEST_REPO}/pkgs/orca-ide/"
ln -s update-prebuilt-github.sh "${TEST_REPO}/scripts/update-orca-ide.sh"
mkdir -p "${TEST_REPO}/pkgs/emdash"
cp "${repo_root}/pkgs/emdash/default.nix" "${TEST_REPO}/pkgs/emdash/"
ln -s update-prebuilt-github.sh "${TEST_REPO}/scripts/update-emdash.sh"
mkdir -p "${TEST_REPO}/pkgs/paseo-desktop"
cp "${repo_root}/pkgs/paseo-desktop/default.nix" "${TEST_REPO}/pkgs/paseo-desktop/"
ln -s update-prebuilt-github.sh "${TEST_REPO}/scripts/update-paseo-desktop.sh"
mkdir -p "${TEST_REPO}/pkgs/pandacode"
cp "${repo_root}/pkgs/pandacode/default.nix" "${TEST_REPO}/pkgs/pandacode/"
ln -s update-prebuilt-github.sh "${TEST_REPO}/scripts/update-pandacode.sh"
mkdir -p "${TEST_REPO}/pkgs/agent-orchestrator"
cp "${repo_root}/pkgs/agent-orchestrator/default.nix" "${TEST_REPO}/pkgs/agent-orchestrator/"
ln -s update-prebuilt-github.sh "${TEST_REPO}/scripts/update-agent-orchestrator.sh"
mkdir -p "${TEST_REPO}/pkgs/kandev"
cp "${repo_root}/pkgs/kandev/default.nix" "${TEST_REPO}/pkgs/kandev/"
ln -s update-prebuilt-github.sh "${TEST_REPO}/scripts/update-kandev.sh"
mkdir -p "${TEST_REPO}/pkgs/superset"
cp "${repo_root}/pkgs/superset/default.nix" "${TEST_REPO}/pkgs/superset/"
ln -s update-prebuilt-github.sh "${TEST_REPO}/scripts/update-superset.sh"
cp "${repo_root}/scripts/update-codex.sh" "${TEST_REPO}/scripts/"
cp "${repo_root}/pkgs/codex/default.nix" "${TEST_REPO}/pkgs/codex/"
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
if [[ "$*" == *files.cmux.com/cmux-tui/latest/manifest.json* ]]; then
    printf '{"commit":"%s","builtAt":"2026-10-19T18:02:07-07:00","binaries":{' "${TEST_CMUX_REV:-0123456789012345678901234567890123456789}"
    printf '"cmux-tui-x86_64-unknown-linux-musl":"%064d",' 0
    printf '"cmux-tui-aarch64-unknown-linux-musl":"%064d",' 1
    printf '"cmux-tui-x86_64-apple-darwin":"%064d"' 2
    if [[ "${TEST_CMUX_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',"cmux-tui-aarch64-apple-darwin":"%s"' "${TEST_CMUX_HASH:-$(printf '%064d' 3)}"
    fi
    printf '}}\n'
elif [[ "$*" == *acli.atlassian.com* ]]; then
    cp "${TEST_ACLI_ARCHIVE}" "${@: -1}"
elif [[ "$*" == *opencode.ai/update/api/latest/cli/npm* ]]; then
    printf '{"version":"%s","metadata":{"package":"@opencode/cli"}}\n' "${TEST_OPENCODE_RELEASE:-2.1.0}"
elif [[ "$*" == *registry.npmjs.org/@opencode%2fcli-* ]]; then
    target="${@: -1}"
    version="${target##*/}"
    target="${target#https://registry.npmjs.org/@opencode%2fcli-}"
    target="${target%/*}"
    if [[ "${TEST_OPENCODE_MISSING_TARGET:-}" == "$target" ]]; then exit 22; fi
    hash="sha512-$(printf '%086s' '' | tr ' ' A)=="
    if [[ "${TEST_OPENCODE_BAD_HASH:-0}" == 1 ]]; then hash=invalid; fi
    printf '{"name":"@opencode/cli-%s","version":"%s","dist":{"integrity":"%s"}}\n' "$target" "$version" "$hash"
elif [[ "$*" == *pypi.org/pypi/semble/json* ]]; then
    printf '{"info":{"version":"0.10.0"},"urls":[{"packagetype":"sdist","yanked":false,"url":"https://files.pythonhosted.org/semble-0.10.0.tar.gz"}]}\n'
else
    printf '{"tag_name":"%s"}\n' "${TEST_RELEASE:-3.3.0}"
fi
EOF
cat >"${test_root}/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == api ]]
if [[ "$2" == repos/superset-sh/superset/releases/latest ]]; then
    printf '{"tag_name":"%s","assets":[' "${TEST_SUPERSET_RELEASE:-desktop-v2.0.0}"
    printf '{"name":"superset-2.0.0-x86_64.AppImage","digest":"sha256:%064d"},' 0
    printf '{"name":"Superset-2.0.0-mac.zip","digest":"sha256:%064d"}' 1
    if [[ "${TEST_SUPERSET_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',{"name":"Superset-2.0.0-arm64-mac.zip","digest":"sha256:%064d"}' 2
    fi
    printf ']}\n'
    exit
fi
if [[ "$2" == repos/kdlbs/kandev/releases/latest ]]; then
    printf '{"tag_name":"v2.0.0","assets":['
    printf '{"name":"kandev-desktop-linux-x64-Kandev_2.0.0_amd64.AppImage","digest":"sha256:%064d"},' 0
    printf '{"name":"kandev-desktop-linux-arm64-Kandev_2.0.0_aarch64.AppImage","digest":"sha256:%064d"},' 1
    printf '{"name":"kandev-desktop-macos-x64-Kandev.app.tar.gz","digest":"sha256:%064d"}' 2
    if [[ "${TEST_KANDEV_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',{"name":"kandev-desktop-macos-arm64-Kandev.app.tar.gz","digest":"sha256:%064d"}' 3
    fi
    printf ']}\n'
    exit
fi
if [[ "$2" == repos/OrchestratorInc/agent-orchestrator/releases/latest ]]; then
    printf '{"tag_name":"v2.0.0","assets":['
    printf '{"name":"agent-orchestrator-linux-x64.AppImage","digest":"sha256:%064d"},' 0
    printf '{"name":"agent-orchestrator-darwin-x64.zip","digest":"sha256:%064d"}' 1
    if [[ "${TEST_AO_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',{"name":"agent-orchestrator-darwin-arm64.zip","digest":"sha256:%064d"}' 2
    fi
    printf ']}\n'
    exit
fi
if [[ "$2" == repos/aicodeking/pandacode/releases/latest ]]; then
    printf '{"tag_name":"v2.0.0","assets":['
    printf '{"name":"PandaCode-Linux-x86_64.AppImage","digest":"sha256:%064d"},' 0
    printf '{"name":"PandaCode-Linux-aarch64.AppImage","digest":"sha256:%064d"}' 1
    if [[ "${TEST_PANDACODE_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',{"name":"PandaCode-macOS-arm64.app.tar.gz","digest":"sha256:%064d"}' 2
    fi
    printf ']}\n'
    exit
fi
if [[ "$2" == repos/getpaseo/paseo/releases/latest ]]; then
    printf '{"tag_name":"v2.0.0","assets":['
    printf '{"name":"Paseo-x86_64.AppImage","digest":"sha256:%064d"},' 0
    printf '{"name":"Paseo-2.0.0-x64.zip","digest":"sha256:%064d"}' 1
    if [[ "${TEST_PASEO_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',{"name":"Paseo-2.0.0-arm64.zip","digest":"sha256:%064d"}' 2
    fi
    printf ']}\n'
    exit
fi
if [[ "$2" == repos/generalaction/emdash/releases/latest ]]; then
    printf '{"tag_name":"v2.0.0","assets":['
    printf '{"name":"emdash-x86_64.AppImage","digest":"sha256:%064d"},' 0
    printf '{"name":"emdash-arm64.AppImage","digest":"sha256:%064d"},' 1
    printf '{"name":"emdash-x64.zip","digest":"sha256:%064d"}' 2
    if [[ "${TEST_EMDASH_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',{"name":"emdash-arm64.zip","digest":"sha256:%064d"}' 3
    fi
    printf ']}\n'
    exit
fi
if [[ "$2" == repos/stablyai/orca/releases/latest ]]; then
    printf '{"tag_name":"v2.0.0","assets":['
    printf '{"name":"orca-linux.AppImage","digest":"sha256:%064d"},' 0
    printf '{"name":"orca-linux-arm64.AppImage","digest":"sha256:%064d"},' 1
    printf '{"name":"Orca-2.0.0-mac.zip","digest":"sha256:%064d"}' 2
    if [[ "${TEST_ORCA_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',{"name":"Orca-2.0.0-arm64-mac.zip","digest":"sha256:%064d"}' 3
    fi
    printf ']}\n'
    exit
fi
if [[ "$2" == repos/openai/codex/releases/latest ]]; then
    printf '{"tag_name":"%s","assets":[' "${TEST_CODEX_RELEASE:-rust-v0.200.0}"
    printf '{"name":"codex-package-x86_64-unknown-linux-musl.tar.gz","digest":"sha256:%064d"}' 0
    if [[ "${TEST_CODEX_MISSING_ASSET:-0}" == 0 ]]; then
        printf ',{"name":"codex-package-aarch64-apple-darwin.tar.gz","digest":"sha256:%064d"}' 1
    fi
    printf ']}\n'
    exit
fi
printf '{"tag_name":"%s"}\n' "${TEST_RELEASE:-3.3.0}"
EOF
cat >"${test_root}/bin/nix" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == store ]]; then
    if [[ "$*" == *opencode.ai/files/bin/* && "${TEST_OPENCODE_MISSING_DESKTOP:-0}" == 1 ]]; then exit 1; fi
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

"${TEST_REPO}/scripts/update-opencode-v2.sh" --dry-run >/dev/null
for package in opencode-v2 opencode-v2-desktop; do
    cmp "${repo_root}/pkgs/${package}/default.nix" "${TEST_REPO}/pkgs/${package}/default.nix"
done
test ! -e "${TEST_REPO}/builds.log"
"${TEST_REPO}/scripts/update-opencode-v2.sh" >/dev/null
for package in opencode-v2 opencode-v2-desktop; do
    rg -q 'version = "2.1.0";' "${TEST_REPO}/pkgs/${package}/default.nix"
done
test "$(rg -c 'hash = "sha512-A{86}==";' "${TEST_REPO}/pkgs/opencode-v2/default.nix")" = 4
rg -q 'hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";' "${TEST_REPO}/pkgs/opencode-v2-desktop/default.nix"
rg -q '^build path:.#opencode-v2 path:.#opencode-v2-desktop --no-link --no-write-lock-file$' "${TEST_REPO}/builds.log"
cp "${TEST_REPO}/builds.log" "${test_root}/builds.before"
"${TEST_REPO}/scripts/update-opencode-v2.sh" >/dev/null
cmp "${test_root}/builds.before" "${TEST_REPO}/builds.log"
for failure in major target integrity desktop build; do
    for package in opencode-v2 opencode-v2-desktop; do
        cp "${repo_root}/pkgs/${package}/default.nix" "${TEST_REPO}/pkgs/${package}/default.nix"
        printf '# existing user changes\n' >>"${TEST_REPO}/pkgs/${package}/default.nix"
        cp "${TEST_REPO}/pkgs/${package}/default.nix" "${test_root}/${package}.before"
    done
    export TEST_OPENCODE_RELEASE=2.1.0 TEST_OPENCODE_MISSING_TARGET='' TEST_OPENCODE_BAD_HASH=0 TEST_OPENCODE_MISSING_DESKTOP=0 TEST_BUILD_FAILURE=0
    case "$failure" in
    major) TEST_OPENCODE_RELEASE=3.0.0 ;;
    target) TEST_OPENCODE_MISSING_TARGET=darwin-arm64 ;;
    integrity) TEST_OPENCODE_BAD_HASH=1 ;;
    desktop) TEST_OPENCODE_MISSING_DESKTOP=1 ;;
    build) TEST_BUILD_FAILURE=1 ;;
    esac
    if "${TEST_REPO}/scripts/update-opencode-v2.sh" >/dev/null 2>&1; then
        echo "Expected OpenCode $failure failure" >&2
        exit 1
    fi
    for package in opencode-v2 opencode-v2-desktop; do
        cmp "${test_root}/${package}.before" "${TEST_REPO}/pkgs/${package}/default.nix"
    done
done
unset TEST_OPENCODE_RELEASE TEST_OPENCODE_MISSING_TARGET TEST_OPENCODE_BAD_HASH TEST_OPENCODE_MISSING_DESKTOP TEST_BUILD_FAILURE

"${TEST_REPO}/scripts/update-cmux-tui.sh" >/dev/null
rg -q 'rev = "0123456789012345678901234567890123456789";' "${TEST_REPO}/pkgs/cmux-tui/default.nix"
rg -q 'version = "0.1.0-unstable-2026-10-20";' "${TEST_REPO}/pkgs/cmux-tui/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/cmux-tui/default.nix")" -eq 4 ]]
rg -q '^build .#cmux-tui --no-link$' "${TEST_REPO}/builds.log"
for failure in commit asset hash build; do
    cp "${repo_root}/pkgs/cmux-tui/default.nix" "${TEST_REPO}/pkgs/cmux-tui/default.nix"
    printf '# existing user changes\n' >>"${TEST_REPO}/pkgs/cmux-tui/default.nix"
    cp "${TEST_REPO}/pkgs/cmux-tui/default.nix" "${test_root}/cmux.before"
    export TEST_CMUX_REV=0123456789012345678901234567890123456789 TEST_CMUX_MISSING_ASSET=0 TEST_CMUX_HASH='' TEST_BUILD_FAILURE=0
    case "${failure}" in
    commit) TEST_CMUX_REV=invalid ;;
    asset) TEST_CMUX_MISSING_ASSET=1 ;;
    hash) TEST_CMUX_HASH=invalid ;;
    build) TEST_BUILD_FAILURE=1 ;;
    esac
    if "${TEST_REPO}/scripts/update-cmux-tui.sh" >/dev/null 2>&1; then
        echo "Expected cmux ${failure} failure" >&2
        exit 1
    fi
    cmp "${test_root}/cmux.before" "${TEST_REPO}/pkgs/cmux-tui/default.nix"
done
unset TEST_CMUX_REV TEST_CMUX_MISSING_ASSET TEST_CMUX_HASH TEST_BUILD_FAILURE

TEST_OPENCODE_RELEASE=3.0.0 "${TEST_REPO}/scripts/update-opencode-v2-desktop.sh" 2.1.0 >/dev/null
for package in opencode-v2 opencode-v2-desktop; do
    rg -q 'version = "2.1.0";' "${TEST_REPO}/pkgs/${package}/default.nix"
done

"${TEST_REPO}/scripts/update-orca-ide.sh" >/dev/null
rg -q 'version = "2.0.0";' "${TEST_REPO}/pkgs/orca-ide/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/orca-ide/default.nix")" -eq 4 ]]
rg -q '^build .#orca-ide --no-link$' "${TEST_REPO}/builds.log"
cp "${repo_root}/pkgs/orca-ide/default.nix" "${TEST_REPO}/pkgs/orca-ide/"
if TEST_ORCA_MISSING_ASSET=1 "${TEST_REPO}/scripts/update-orca-ide.sh" >/dev/null 2>&1; then
    echo 'Expected Orca missing asset failure' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/orca-ide/default.nix" "${TEST_REPO}/pkgs/orca-ide/default.nix"

"${TEST_REPO}/scripts/update-emdash.sh" >/dev/null
rg -q 'version = "2.0.0";' "${TEST_REPO}/pkgs/emdash/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/emdash/default.nix")" -eq 4 ]]
rg -q '^build .#emdash --no-link$' "${TEST_REPO}/builds.log"
cp "${repo_root}/pkgs/emdash/default.nix" "${TEST_REPO}/pkgs/emdash/"
if TEST_EMDASH_MISSING_ASSET=1 "${TEST_REPO}/scripts/update-emdash.sh" >/dev/null 2>&1; then
    echo 'Expected Emdash missing asset failure' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/emdash/default.nix" "${TEST_REPO}/pkgs/emdash/default.nix"

"${TEST_REPO}/scripts/update-pandacode.sh" >/dev/null
rg -q 'version = "2.0.0";' "${TEST_REPO}/pkgs/pandacode/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/pandacode/default.nix")" -eq 3 ]]
rg -q '^build .#pandacode --no-link$' "${TEST_REPO}/builds.log"
cp "${repo_root}/pkgs/pandacode/default.nix" "${TEST_REPO}/pkgs/pandacode/"
if TEST_PANDACODE_MISSING_ASSET=1 "${TEST_REPO}/scripts/update-pandacode.sh" >/dev/null 2>&1; then
    echo 'Expected PandaCode missing asset failure' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/pandacode/default.nix" "${TEST_REPO}/pkgs/pandacode/default.nix"

"${TEST_REPO}/scripts/update-paseo-desktop.sh" >/dev/null
rg -q 'version = "2.0.0";' "${TEST_REPO}/pkgs/paseo-desktop/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/paseo-desktop/default.nix")" -eq 3 ]]
rg -q '^build .#paseo-desktop --no-link$' "${TEST_REPO}/builds.log"
cp "${repo_root}/pkgs/paseo-desktop/default.nix" "${TEST_REPO}/pkgs/paseo-desktop/"
if TEST_PASEO_MISSING_ASSET=1 "${TEST_REPO}/scripts/update-paseo-desktop.sh" >/dev/null 2>&1; then
    echo 'Expected Paseo missing asset failure' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/paseo-desktop/default.nix" "${TEST_REPO}/pkgs/paseo-desktop/default.nix"

"${TEST_REPO}/scripts/update-agent-orchestrator.sh" >/dev/null
rg -q 'version = "2.0.0";' "${TEST_REPO}/pkgs/agent-orchestrator/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/agent-orchestrator/default.nix")" -eq 3 ]]
rg -q '^build .#agent-orchestrator --no-link$' "${TEST_REPO}/builds.log"
cp "${repo_root}/pkgs/agent-orchestrator/default.nix" "${TEST_REPO}/pkgs/agent-orchestrator/"
if TEST_AO_MISSING_ASSET=1 "${TEST_REPO}/scripts/update-agent-orchestrator.sh" >/dev/null 2>&1; then
    echo 'Expected Agent Orchestrator missing asset failure' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/agent-orchestrator/default.nix" "${TEST_REPO}/pkgs/agent-orchestrator/default.nix"

"${TEST_REPO}/scripts/update-kandev.sh" >/dev/null
rg -q 'version = "2.0.0";' "${TEST_REPO}/pkgs/kandev/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/kandev/default.nix")" -eq 4 ]]
rg -q '^build .#kandev --no-link$' "${TEST_REPO}/builds.log"
cp "${repo_root}/pkgs/kandev/default.nix" "${TEST_REPO}/pkgs/kandev/"
if TEST_KANDEV_MISSING_ASSET=1 "${TEST_REPO}/scripts/update-kandev.sh" >/dev/null 2>&1; then
    echo 'Expected Kandev missing asset failure' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/kandev/default.nix" "${TEST_REPO}/pkgs/kandev/default.nix"

"${TEST_REPO}/scripts/update-superset.sh" >/dev/null
rg -q 'version = "2.0.0";' "${TEST_REPO}/pkgs/superset/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/superset/default.nix")" -eq 3 ]]
rg -q '^build .#superset --no-link$' "${TEST_REPO}/builds.log"
for failure in asset tag; do
    cp "${repo_root}/pkgs/superset/default.nix" "${TEST_REPO}/pkgs/superset/"
    export TEST_SUPERSET_RELEASE=desktop-v2.0.0 TEST_SUPERSET_MISSING_ASSET=0
    if [[ "$failure" == tag ]]; then TEST_SUPERSET_RELEASE=v2.0.0; else TEST_SUPERSET_MISSING_ASSET=1; fi
    if "${TEST_REPO}/scripts/update-superset.sh" >/dev/null 2>&1; then
        echo "Expected Superset ${failure} failure" >&2
        exit 1
    fi
    cmp "${repo_root}/pkgs/superset/default.nix" "${TEST_REPO}/pkgs/superset/default.nix"
done
unset TEST_SUPERSET_RELEASE TEST_SUPERSET_MISSING_ASSET

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

"${TEST_REPO}/scripts/update-codex.sh" >/dev/null
rg -q 'version = "0.200.0";' "${TEST_REPO}/pkgs/codex/default.nix"
[[ "$(rg -c 'hash = "sha256-TESTHASH";' "${TEST_REPO}/pkgs/codex/default.nix")" -eq 2 ]]
for failure in tag asset; do
    cp "${repo_root}/pkgs/codex/default.nix" "${TEST_REPO}/pkgs/codex/"
    export TEST_CODEX_RELEASE=rust-v0.200.0 TEST_CODEX_MISSING_ASSET=0
    if [[ "$failure" == tag ]]; then TEST_CODEX_RELEASE=rust-v0.200.0-alpha; else TEST_CODEX_MISSING_ASSET=1; fi
    if "${TEST_REPO}/scripts/update-codex.sh" >/dev/null 2>&1; then
        echo "Expected Codex ${failure} failure" >&2
        exit 1
    fi
    cmp "${repo_root}/pkgs/codex/default.nix" "${TEST_REPO}/pkgs/codex/default.nix"
done
export TEST_CODEX_RELEASE=rust-v0.200.0 TEST_CODEX_MISSING_ASSET=0

export TEST_BUILD_FAILURE=1
cp "${repo_root}/pkgs/acli/default.nix" "${TEST_REPO}/pkgs/acli/default.nix"
if "${TEST_REPO}/scripts/update-acli.sh" >/dev/null 2>&1; then
    echo 'Expected acli build failure' >&2
    exit 1
fi
cmp "${repo_root}/pkgs/acli/default.nix" "${TEST_REPO}/pkgs/acli/default.nix"
for package in jpegli semble codex; do
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
bash "${TEST_REPO}/scripts/update-databricks-agent-skills.sh" >/dev/null
rg -q '^updated input$' "${TEST_REPO}/flake.lock"
rg -q '^build .#databricks-agent-skills --no-link$' "${TEST_REPO}/builds.log"

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
