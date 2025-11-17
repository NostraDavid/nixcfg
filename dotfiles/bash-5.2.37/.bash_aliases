#!/usr/bin/env bash

alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias getsizes='du -h . | sort -rh | head -5'
alias gitbulk='git verify-pack -v .git/objects/pack/pack-*.idx | sort -k 3 -n | tail -3'
alias gitfilebranch='git log --oneline --branches --' # pass the filename from gitrev
alias gitrev='git rev-list --objects --all | grep'    # pass a hash from gitbulk
alias gitsize='git count-objects -v' # gitsize: size-pack is the repo size in KB
alias gitundo="git reset --soft HEAD~1"
alias grep='grep --color=auto'
alias l='ls -CF'
alias la='ls -A'
alias ll='lsd -lha --group-dirs first --header --blocks permission,user,group,size,date,name --icon=never --color=auto --classify'
alias llo='ls -alhF'
alias ls='ls --color=auto'
alias ncdu='ncdu --color=dark'
alias sudo='sudo '
alias vi='nvim'
alias rplasma='systemctl --user restart plasma-plasmashell.service'
alias generate_gitignore='echo "# ignore all direct items, nonrecursively
/*

# unignore folders
$(ls -l | grep ^d | awk '"'"'{print "!"$NF}'"'"' | sort)

# unignore files
!.bumpversion.cfg
!.gitignore
$(ls -l | grep ^- | awk '"'"'{print "!"$NF}'"'"' | sort)

# reignore subfolders/files *anywhere* in the project
__pycache__
*.egg-info" > .gitignore'

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
        cd "$dir" || exit # Activate the selected environment
    else
        echo "No directory selected."
    fi
}

# == open folder in vscode ==
# usage: code [search_term]
# requires: fzf, fd, code
function code_f() {
    local dir
    if [ -n "$*" ]; then
        dir=$(fd . "$HOME/dev" --no-ignore-vcs --max-depth 2 --type d | fzf --query="$*" -1)
    else
        dir=$(fd . $HOME/dev --no-ignore-vcs --max-depth 2 --type d | fzf --prompt="Select directory: ")
    fi

    # Check if a directory was selected
    if [ -n "$dir" ]; then
        echo "The directory is '$dir'"
        \code "$dir"
    else
        echo "No directory selected."
    fi
}

# we need an alias here, because I need to be able to escape the alias to run the binary
# e.g. \code .
alias code=code_f

function rfc3339() {
    # date | rfc3339
    date --date="$1" --rfc-3339='seconds'
}

function epoch() {
    #  epoch 2021-01-04
    date --date="$1" +%s
}

function now() {
    #  now -> current epoch
    date +%s
}

# == fix ssh agent ==
function fix_ssh() {
    SSH_AUTH_SOCK="$(find /tmp/ssh-* -user "$(whoami)" -name 'agent*' -printf '%T@ %p\n' 2>/dev/null | sort -k 1nr | sed 's/^[^ ]* //' | head -n 1)"
    export SSH_AUTH_SOCK
    if [ -n "$SSH_AUTH_SOCK" ]; then
        echo 'Ok!'
    else
        echo 'Error!'
    fi
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

alias cd=cd_f

# == go to folder and activate venv ==
# Usage: venv [search_term]
function venv() {
    local query="$*"

    # Use fzf to select a directory within ~/dev with a depth of 2, optionally filtered by the query
    local dir
    if [[ -n "$query" ]]; then
        dir=$(find ~/dev -maxdepth 2 -type d | fzf --query="$query" -1 -0)
    else
        dir=$(find ~/dev -maxdepth 2 -type d | fzf --prompt="Select directory: " -1 -0)
    fi

    # If a directory is selected
    if [[ -n "$dir" ]]; then
        cd "$dir" || return

        # Try to activate the virtual environment
        if [[ -f ".venv/bin/activate" ]]; then
            # shellcheck source=/dev/null
            source .venv/bin/activate
        else
            # If activation fails, create a new virtual environment
            uv venv --python 3.11
            if [[ -f ".venv/bin/activate" ]]; then
                # shellcheck source=/dev/null
                source .venv/bin/activate
                uv pip install poetry==2.1.2
            else
                echo "Failed to create or activate virtual environment."
            fi
        fi
    else
        echo "No directory selected."
    fi
}

function create_venv() {
    local python_version="${1:-3.11}"
    uv venv --python "$python_version"
    source .venv/bin/activate
    uv pip install poetry
}
