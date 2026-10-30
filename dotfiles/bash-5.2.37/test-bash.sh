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

(cd "$tmp" && HOME="$tmp" COLORTERM='' TERM=dumb HISTFILE=/dev/null bash --noprofile --rcfile "$tmp/.bashrc" -ic '
    [[ $HISTCONTROL == erasedups:ignoredups:ignorespace ]] || exit 1
    [[ $(type -t path_prepend) == function ]] || exit 1
    [[ $(type -t check_and_activate_venv) == function ]] || exit 1
    [[ $(type -t reset_terminal_mouse) == function ]] || exit 1
    [[ ${PROMPT_COMMAND[*]} == *reset_terminal_mouse* ]] || exit 1
    [[ $(type -t gitbulk) == file ]] || exit 1
    [[ $COLORTERM == truecolor ]] || exit 1
    alias plasma_restart >/dev/null || exit 1
    [[ ${BASH_ALIASES[vi]} == work-vim ]] || exit 1
    alias work_only >/dev/null || exit 1
    for name in ff rfc3339 epoch now fix_ssh draw_colors cd_f venv markdownlint_f; do
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
(cd "$tmp/project" && HOME="$tmp" VIRTUAL_ENV="$tmp/.cache/uv/environments-v2/zellij-workspace-test" VIRTUAL_ENV_PROMPT=launcher PATH="$tmp/.cache/uv/environments-v2/zellij-workspace-test/bin:$PATH" TERM=dumb HISTFILE=/dev/null bash --noprofile --rcfile "$tmp/.bashrc" -ic '
    [[ ${TEST_VENV_ACTIVE:-} == 1 && -z ${VIRTUAL_ENV:-} && -z ${VIRTUAL_ENV_PROMPT:-} ]] || exit 1
    [[ :$PATH: != *:"$HOME/.cache/uv/environments-v2/zellij-workspace-test/bin":* ]] || exit 1
' 2>/dev/null)
(cd "$tmp" && HOME="$tmp" TERM=dumb HISTFILE=/dev/null bash --noprofile --rcfile "$tmp/.bashrc" -ic '
    export VIRTUAL_ENV="$HOME/.cache/uv/environments-v2/zellij-workspace-test"
    export PATH="$VIRTUAL_ENV/bin:$PATH"
    cd_f "$HOME/project" || exit 1
    [[ ${TEST_VENV_ACTIVE:-} == 1 && -z ${VIRTUAL_ENV:-} ]] || exit 1
' 2>/dev/null)
(cd "$tmp" && HOME="$tmp" OSTYPE=darwin24 VIRTUAL_ENV='' TERM=dumb HISTFILE=/dev/null bash --noprofile --rcfile "$tmp/.bashrc" -ic '
    [[ ${BASH_ALIASES[vi]} == work-vim ]] || exit 1
    alias work_only >/dev/null || exit 1
    for name in gitundo grep sed rg diff l la llo ls sudo cd cd.. .. get_filetypes getsizes dsa dka markdownlint; do
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
    [[ ${BASH_ALIASES[grep]} == "grep --color=auto" ]] || exit 1
    [[ ${BASH_ALIASES[ll]} == "lsd --all --icon=never --human-readable --group-dirs=first --long --classify" ]] || exit 1
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

# Check global config selection and retain failures unrelated to CHANGELOG MD024.
cat >"$tmp/available-bin/markdownlint" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$MARKDOWNLINT_TEST_ARGS"
printf '%s' "$MARKDOWNLINT_TEST_STDERR" >&2
exit "$MARKDOWNLINT_TEST_STATUS"
EOF
chmod +x "$tmp/available-bin/markdownlint"
mkdir -p "$tmp/xdg config/markdownlint"
printf '{}\n' >"$tmp/xdg config/markdownlint/config.yaml"
export MARKDOWNLINT_TEST_ARGS="$tmp/markdownlint-args"
export MARKDOWNLINT_TEST_STDERR=$'CHANGELOG.md:3 MD024 Duplicate heading\n'
export MARKDOWNLINT_TEST_STATUS=1
(
    export HOME="$tmp" XDG_CONFIG_HOME="$tmp/xdg config" PATH="$tmp/available-bin:$PATH"
    # shellcheck source=bashrc.d/functions.bash
    source "$root/bashrc.d/functions.bash"
    markdownlint_f 'file with spaces.md' 2>"$tmp/markdownlint-stderr"
    [[ ! -s $tmp/markdownlint-stderr ]]
    [[ $(cat "$MARKDOWNLINT_TEST_ARGS") == $'--config\n'"$XDG_CONFIG_HOME/markdownlint/config.yaml"$'\nfile with spaces.md' ]]

    MARKDOWNLINT_TEST_STDERR+=$'README.md:5 MD013 Line too long\n'
    status=0
    markdownlint_f README.md 2>"$tmp/markdownlint-stderr" || status=$?
    [[ $status == 1 ]]
    [[ $(cat "$tmp/markdownlint-stderr") == 'README.md:5 MD013 Line too long' ]]

    MARKDOWNLINT_TEST_STDERR=
    MARKDOWNLINT_TEST_STATUS=2
    status=0
    markdownlint_f README.md || status=$?
    [[ $status == 2 ]]

    MARKDOWNLINT_TEST_STATUS=0
    unset XDG_CONFIG_HOME
    markdownlint_f README.md
    [[ $(cat "$MARKDOWNLINT_TEST_ARGS") == README.md ]]
    COLORTERM=24bit
    # shellcheck source=bashrc.d/environment.bash
    source "$root/bashrc.d/environment.bash"
    [[ $COLORTERM == 24bit ]]
)

BASH_TEST_ROOT="$root" BASH_TEST_BINARY="$bash_bin" python3 - <<'PY'
import os
import subprocess

command = [
    os.environ["BASH_TEST_BINARY"], "--noprofile", "--norc", "-c",
    'source "$1"; false; reset_terminal_mouse; printf "\\nEXIT_STATUS=%s\\n" "$?"',
    "test", os.environ["BASH_TEST_ROOT"] + "/bashrc.d/prompt.bash",
]
reset = b"\x1b[?9;1000;1002;1003l"
for term in ("xterm-256color", "dumb"):
    master, slave = os.openpty()
    try:
        subprocess.run(command, stdin=subprocess.DEVNULL, stdout=slave,
                       stderr=subprocess.PIPE, env=os.environ | {"TERM": term},
                       check=True)
        os.close(slave)
        slave = None
        output = b""
        while True:
            try:
                part = os.read(master, 4096)
            except OSError:
                break
            if not part:
                break
            output += part
        assert (reset in output) == (term != "dumb"), (term, output)
        assert b"EXIT_STATUS=1" in output, output
    finally:
        if slave is not None:
            os.close(slave)
        os.close(master)
result = subprocess.run(command, capture_output=True, check=True,
                        env=os.environ | {"TERM": "xterm-256color"})
assert reset not in result.stdout, result.stdout
assert b"EXIT_STATUS=1" in result.stdout, result.stdout
print("Mouse reset preserves exit status and skips dumb/non-TTY output.")
PY
