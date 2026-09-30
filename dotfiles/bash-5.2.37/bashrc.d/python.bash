# == python 3.7+ ==
# https://docs.python.org/3/using/cmdline.html#envvar-PYTHONDEVMODE
export PYTHONDEVMODE=1
# moves all __pycache__ directories into ~/.cache/cpython to remove project clutter
export PYTHONPYCACHEPREFIX="$HOME/.cache/cpython/"
export PYTHON_KEYRING_BACKEND=keyring.backends.fail.Keyring

# Auto-activate Python virtual environment when opening a shell
function clear_inherited_uv_build_venv() {
    case "${VIRTUAL_ENV:-}" in
    "$HOME"/.cache/uv/builds-v*/.tmp*)
        path_remove "$VIRTUAL_ENV/bin"
        unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
        export PATH
        ;;
    esac
}

function check_and_activate_venv() {
    if [[ -z "$VIRTUAL_ENV" ]]; then
        # If env folder is found then activate the virtualenv
        if [[ -d ./.venv ]]; then
            # shellcheck source=/dev/null
            source .venv/bin/activate
        fi
    fi
}

# Run the check when shell starts
clear_inherited_uv_build_venv
check_and_activate_venv

# pip bash completion start
function _pip_completion() {
    mapfile -t COMPREPLY < <(COMP_WORDS="${COMP_WORDS[*]}" \
        COMP_CWORD=$COMP_CWORD \
        PIP_AUTO_COMPLETE=1 $1 2>/dev/null)
}
if has_builtin complete; then
    complete -o default -F _pip_completion pip
fi
# pip bash completion end
