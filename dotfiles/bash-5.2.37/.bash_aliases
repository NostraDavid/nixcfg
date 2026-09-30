#!/usr/bin/env bash

alias gitfilebranch='git log --oneline --branches --'
alias gitrev='git rev-list --objects --all | grep'
alias gitsize='git count-objects -v'
alias gitundo='git reset --soft HEAD~1'
alias vi='nvim'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias ......='cd ../../../../../'
alias .......='cd ../../../../../../'

alias egrep='grep -E --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep -E --color=auto'
alias sed='sed -E'
alias rg='rg -S'
alias diff='diff --color=auto'
alias l='ls -CF'
alias la='ls -A'
alias llo='ls -alhF'
alias ls='ls --color=auto'
alias sudo='sudo '
alias cd=cd_f

missing_alias_commands=
if command -v lsd >/dev/null 2>&1; then
    alias ll='lsd -lha --group-dirs first --header --blocks permission,user,group,size,date,name --icon=never --color=auto --classify'
else
    missing_alias_commands+=' lsd'
fi
if command -v ncdu >/dev/null 2>&1; then
    alias ncdu='ncdu --color=dark'
else
    missing_alias_commands+=' ncdu'
fi
if command -v project_color >/dev/null 2>&1; then
    alias project_color_preview='project_color --preview'
    alias project-color=project_color
    alias project-colour=project_color
    alias pc=project_color
else
    missing_alias_commands+=' project_color'
fi
if [[ -n $missing_alias_commands ]]; then
    printf '\033[33mOntbreekt: %s\033[0m\n' "${missing_alias_commands# }" >&2
fi
unset missing_alias_commands

if [[ $OSTYPE == linux* ]]; then
    alias ip='ip -c'
    alias plasma_restart='systemctl --user restart plasma-plasmashell.service'
    alias sc-services-all='systemctl list-unit-files --type=service'
    alias sc-services-enabled='systemctl list-unit-files --type=service --state=enabled'
    alias sc-services-running='systemctl list-units --type=service --state=running'
    alias sc-sockets='systemctl list-units --type=socket'
    alias sc-timers='systemctl list-units --type=timer'

    alias ss-listen-all='ss --listening --numeric --processes'
    alias ss-listen-v4='ss --listening --numeric --tcp --udp --ipv4 --processes'
    alias ss-listen-v6='ss --listening --numeric --tcp --udp --ipv6 --processes'
    alias ss-listen='ss --listening --numeric --tcp --udp --processes'
    alias ss-summary='ss --summary'
    alias ss-unix-listen='ss --listening --numeric --unix --processes'
fi

if [ -f "$HOME/.bash_aliases.work" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bash_aliases.work"
fi
