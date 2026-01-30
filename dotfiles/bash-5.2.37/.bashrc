#!/usr/bin/env bash

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Flatpak desktop entries
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# make ls output iso8601
export TIME_STYLE=long-iso

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# $- is the shell options, so we're grabbing the index of 'i' within $-
iatest=$(expr index "$-" i)

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=-1
# Don't put duplicate lines in the history and do not add lines that start with a space
HISTCONTROL=erasedups:ignoredups:ignorespace
# my god this is good! <3 `history`
HISTTIMEFORMAT="%F %T "

# enables bash to write a command immediately after execution
PROMPT_COMMAND='history -a; history -n'

# Allow ctrl-S for history navigation (with ctrl-R)
stty -ixon

# Ignore case on auto-completion
# Note: bind used instead of sticking these in .inputrc
if [[ $iatest -gt 0 ]]; then bind "set completion-ignore-case on"; fi

# Show auto-completion list automatically, without double tab
if [[ $iatest -gt 0 ]]; then bind "set show-all-if-ambiguous On"; fi

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

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

use_starship_prompt=
if command -v starship >/dev/null 2>&1; then
    use_starship_prompt=1
fi

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -z "$use_starship_prompt" ]; then
    if [ -n "$force_color_prompt" ]; then
        if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
            # We have color support; assume it's compliant with Ecma-48
            # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
            # a case would tend to support setf rather than setaf.)
            color_prompt=yes
        else
            color_prompt=
        fi
    fi

    if [ "$color_prompt" = yes ]; then
        PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    else
        PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
    fi
    unset color_prompt force_color_prompt

    # If this is an xterm set the title to user@host:dir
    case "$TERM" in
    xterm* | rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
    *) ;;
    esac
else
    unset color_prompt force_color_prompt
fi

# enable color support of ls
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f "$HOME/.bash_aliases" ]; then
    source "$HOME/.bash_aliases"
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Disable the bell
if [[ $iatest -gt 0 ]]; then bind "set bell-style visible"; fi

# == shopts ==
# https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
shopt -s autocd         # cd into folder without cd, so 'dotfiles' will cd into the folder
shopt -s cdspell        # attempt spelling correcting on folders
shopt -s direxpand      # expand a partial dir name
shopt -s checkjobs      # stop shell from exit when there's jobs running
shopt -s dirspell       # attempt spelling correcting on folders
shopt -s expand_aliases # aliases are expanded
shopt -s histappend     # append to the history file, don't overwrite it
shopt -s histreedit     # lets your re-edit old executed command
shopt -s histverify     # I'm confused.
shopt -s hostcomplete   # performs completion when a word contains an '@'
shopt -s cmdhist        # save multiple-line command in single history entry
shopt -u lithist        # multi-lines are saved with embedded newlines rather than semicolons; explictly unset
shopt -s checkwinsize   # update LINES and COLUMNS to fit output

# == other ==
#export PAGER="most" # better color support than `less`
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

# == Powerline prompt ==
# `sudo apt install powerline powerline-gitstatus`
# Actual location:
# /nix/store/37lnwwvibh01mihs3dn3fkxjqxss6lzw-python3.12-powerline-2.8.4/share/bash/powerline.sh
# if [ -f /etc/profiles/per-user/david/share/bash/powerline.sh ]; then
#     powerline-daemon -q 2>/dev/null
#     POWERLINE_BASH_CONTINUATION=1
#     POWERLINE_BASH_SELECT=1
#     source /etc/profiles/per-user/david/share/bash/powerline.sh
# elif [ -f "$HOME/.nix-profile/share/bash/powerline.sh" ]; then
#     powerline-daemon -q 2>/dev/null
#     POWERLINE_BASH_CONTINUATION=1
#     POWERLINE_BASH_SELECT=1
#     source "$HOME/.nix-profile/share/bash/powerline.sh"
# fi

# == python 3.7+ ==
# https://docs.python.org/3/using/cmdline.html#envvar-PYTHONDEVMODE
export PYTHONDEVMODE=1
# moves all __pycache__ directories into ~/.cache/cpython to remove project clutter
export PYTHONPYCACHEPREFIX="$HOME/.cache/cpython/"
export PYTHON_KEYRING_BACKEND=keyring.backends.fail.Keyring

# Auto-activate Python virtual environment when opening a shell
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
check_and_activate_venv

# pip bash completion start
function _pip_completion() {
    mapfile -t COMPREPLY < <(COMP_WORDS="${COMP_WORDS[*]}" \
        COMP_CWORD=$COMP_CWORD \
        PIP_AUTO_COMPLETE=1 $1 2>/dev/null)
}
complete -o default -F _pip_completion pip
# pip bash completion end

# == tmux addon ==
tmux-git-autofetch() { ("$HOME/.tmux/plugins/tmux-git-autofetch/git-autofetch.tmux" --current &) }

# == ensure ctrl-d doesn't fuck up tmux ==
if [[ -n "$TMUX" ]]; then
    # Ignore EOF (Ctrl+D) in tmux sessions
    set -o ignoreeof
fi

# == starship prompt ==
if [ -n "$use_starship_prompt" ]; then
    eval "$(starship init bash)"
fi

# == github copilot ==
# Installation: `gh extension install github/gh-copilot``
eval "$(gh copilot alias -- bash)"

# == fzf-bash integration via ctrl-r ==
if [ -n "${XDG_DATA_DIRS-}" ]; then
  for dir in ${XDG_DATA_DIRS//:/ }; do
    [ -f "$dir/fzf/completion.bash" ] && source "$dir/fzf/completion.bash"
    [ -f "$dir/fzf/key-bindings.bash" ] && source "$dir/fzf/key-bindings.bash"
  done
fi
