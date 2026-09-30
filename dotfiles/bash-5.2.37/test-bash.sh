#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/.local"
ln -s "$root/.bashrc" "$tmp/managed-bashrc"
ln -s managed-bashrc "$tmp/.bashrc"
ln -s "$root/bashrc.d" "$tmp/.bashrc.d"
ln -s "$root/.bash_aliases" "$tmp/.bash_aliases"
ln -s "$root/../ndtk/.local/bin" "$tmp/.local/bin"
cat >"$tmp/.bash_aliases.work" <<'EOF'
alias vi='work-vim'
alias work_only='printf work'
EOF
cat >"$tmp/.bashrc.work" <<'EOF'
printf 'work\n' >> "$HOME/hook-order"
EOF
cat >"$tmp/.bashrc.local" <<'EOF'
printf 'local\n' >> "$HOME/hook-order"
EOF

(cd "$tmp" && HOME="$tmp" TERM=dumb HISTFILE=/dev/null bash --noprofile --rcfile "$tmp/.bashrc" -ic '
    [[ $HISTCONTROL == erasedups:ignoredups:ignorespace ]] || exit 1
    [[ $(type -t path_prepend) == function ]] || exit 1
    [[ $(type -t check_and_activate_venv) == function ]] || exit 1
    [[ $(type -t gitbulk) == file ]] || exit 1
    alias plasma_restart >/dev/null || exit 1
    [[ ${BASH_ALIASES[vi]} == work-vim ]] || exit 1
    alias work_only >/dev/null || exit 1
    for name in ff rfc3339 epoch now fix_ssh draw_colors cd_f venv; do
        [[ $(type -t "$name") == function ]] || exit 1
    done
    alias cd | grep -q cd_f
    alias pc | grep -q project_color
    fzf() { printf "%s\n" "$HOME/missing-directory"; }
    if ff >/dev/null 2>&1; then exit 1; fi
' 2>/dev/null)
[[ $(cat "$tmp/hook-order") == $'work\nlocal' ]]

mkdir -p "$tmp/project/.venv/bin"
printf 'export TEST_VENV_ACTIVE=1\n' >"$tmp/project/.venv/bin/activate"
(cd "$tmp" && HOME="$tmp" OSTYPE=darwin24 VIRTUAL_ENV='' TERM=dumb HISTFILE=/dev/null bash --noprofile --rcfile "$tmp/.bashrc" -ic '
    [[ ${BASH_ALIASES[vi]} == work-vim ]] || exit 1
    alias work_only >/dev/null || exit 1
    for name in gitundo grep sed rg diff l la llo ls sudo cd; do
        alias "$name" >/dev/null || exit 1
    done
    for name in ff now draw_colors cd_f; do
        [[ $(type -t "$name") == function ]] || exit 1
    done
    for name in ip plasma_restart sc-timers ss-listen; do
        if alias "$name" >/dev/null 2>&1; then exit 1; fi
    done
    for name in rfc3339 epoch fix_ssh venv; do
        if declare -F "$name" >/dev/null; then exit 1; fi
    done
    cd "$HOME/project"
    [[ $TEST_VENV_ACTIVE == 1 ]] || exit 1
' 2>/dev/null)

bash_bin=$(command -v bash)
warning=$(HOME="$tmp" OSTYPE=darwin24 PATH=/nonexistent BASH_ENV="$tmp/.bash_aliases" "$bash_bin" --noprofile --norc -c : 2>&1)
[[ $warning == $'\033[33mOntbreekt: lsd ncdu project_color\033[0m' ]]

mkdir -p "$tmp/available-bin"
for name in lsd ncdu project_color; do
    printf '#!/bin/sh\nexit 0\n' >"$tmp/available-bin/$name"
    chmod +x "$tmp/available-bin/$name"
done
warning=$(HOME="$tmp" OSTYPE=darwin24 PATH="$tmp/available-bin" BASH_ENV="$tmp/.bash_aliases" "$bash_bin" --noprofile --norc -c : 2>&1)
[[ -z $warning ]]

rm "$tmp/.bash_aliases.work"
# shellcheck disable=SC2016 # The child shell expands BASH_ALIASES.
HOME="$tmp" PATH="$tmp/available-bin" BASH_ENV="$tmp/.bash_aliases" "$bash_bin" --noprofile --norc -c '
    [[ ${BASH_ALIASES[vi]} == nvim ]] || exit 1
    if alias work_only >/dev/null 2>&1; then exit 1; fi
'

(cd "$tmp" && HOME="$tmp" bash --noprofile -c 'source "$HOME/.bashrc"; [[ $(type -t check_and_activate_venv) != function ]]')

git -C "$tmp" init -q repo
printf 'packed object\n' >"$tmp/repo/data"
git -C "$tmp/repo" add data
git -C "$tmp/repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false -c user.name=Test -c user.email=test@example.invalid commit -qm initial
git -C "$tmp/repo" repack -adq
git -C "$tmp/repo" worktree add --detach -q "$tmp/worktree" HEAD
(cd "$tmp/worktree" && "$root/../ndtk/.local/bin/gitbulk") >"$tmp/gitbulk-output"
[[ -s $tmp/gitbulk-output ]]

git -C "$tmp" init -q empty
if (cd "$tmp/empty" && "$root/../ndtk/.local/bin/gitbulk") >"$tmp/no-pack" 2>&1; then
    exit 1
fi
grep -q 'No Git pack indexes found' "$tmp/no-pack"
