has_builtin() {
    type -t "$1" 2>/dev/null | grep -qx builtin
}

safe_bind() {
    has_builtin bind && bind "$@"
}

safe_shopt() {
    local mode="$1"
    local option="$2"

    has_builtin shopt && shopt "$mode" "$option" 2>/dev/null
}

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=-1
# Don't put duplicate lines in the history and do not add lines that start with a space
HISTCONTROL=erasedups:ignoredups:ignorespace
# my god this is good! <3 `history`
HISTTIMEFORMAT="%F %T "

# Allow ctrl-S for history navigation (with ctrl-R)
if [ -t 0 ]; then
    stty -ixon
fi

set -o emacs

# Ignore case on auto-completion
# Note: bind used instead of sticking these in .inputrc
safe_bind "set completion-ignore-case on"

# Show auto-completion list automatically, without double tab
safe_bind "set show-all-if-ambiguous On"

# set the default editor
export EDITOR=vi
export VISUAL=vi

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
