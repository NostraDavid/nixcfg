# find folder xD
function ff() {
    local dir
    if [ -n "$1" ]; then
        # shellcheck disable=SC2012
        dir=$(ls -d ./*/ | sed 's|/$||' | fzf --query="$1" -1)
    else
        # shellcheck disable=SC2012
        dir=$(ls -d ./*/ | sed 's|/$||' | fzf --prompt="Select directory: ")
    fi

    if [ -n "$dir" ]; then
        builtin cd "$dir" || return
    else
        echo "No directory selected."
    fi
}

function now() {
    #  now -> current epoch
    date +%s
}

# == draw all bash colors ==
function draw_colors() {
    for x in {0..8}; do
        for i in {30..37}; do
            for a in {40..47}; do
                echo -ne "\e[${x};${i};${a}m\\\e[${x};${i};${a}m\e[0;37;40m "
            done
            echo
        done
    done
}

# == auto activate virtualenv ==
function cd_f() {
    builtin cd "$@" || return

    if [[ -z "$VIRTUAL_ENV" ]]; then
        ## If env folder is found then activate the vitualenv
        if [[ -d ./.venv ]]; then
            # shellcheck source=/dev/null
            source .venv/bin/activate
        fi
    else
        ## check the current folder belong to earlier VIRTUAL_ENV folder
        # if yes then do nothing
        # else deactivate
        parentdir="$(dirname "$VIRTUAL_ENV")"
        if [[ "$PWD"/ != "$parentdir"/* ]]; then
            deactivate
        fi
    fi
}

if [[ $OSTYPE == linux* ]]; then
    function rfc3339() {
        date --date="$1" --rfc-3339='seconds'
    }

    function epoch() {
        date --date="$1" +%s
    }

    function fix_ssh() {
        SSH_AUTH_SOCK="$(find /tmp/ssh-* -user "$(whoami)" -name 'agent*' -printf '%T@ %p\n' 2>/dev/null | sort -k 1nr | sed 's/^[^ ]* //' | head -n 1)"
        export SSH_AUTH_SOCK
        if [ -n "$SSH_AUTH_SOCK" ]; then
            echo 'Ok!'
        else
            echo 'Error!'
        fi
    }

    # The venv launcher is installed only with the Linux dotfiles.
    function venv() {
        local commands
        commands=$("$HOME/.local/bin/venv" "$@") || return
        eval "$commands"
    }
fi
