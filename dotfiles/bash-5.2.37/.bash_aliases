#!/usr/bin/env bash

alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias getsizes='du -h . | sort -rh | head -5'
alias gitbulk='git verify-pack -v .git/objects/pack/pack-*.idx | sort -k 3 -n | tail -3'
alias gitfilebranch='git log --oneline --branches --' # pass the filename from gitrev
alias gitrev='git rev-list --objects --all | grep'    # pass a hash from gitbulk
alias gitsize='git count-objects -v'                  # gitsize: size-pack is the repo size in KB
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
alias plasma_restart='systemctl --user restart plasma-plasmashell.service'
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
	local commands
	commands=$("$HOME/.local/bin/venv" "$@") || return
	eval "$commands"
}

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

# == deterministic project folder -> HEX color ==
# Usage:
#   project_color            # prints hex color for current folder name
#   project_color my-folder  # prints hex color for provided name
#   project_color_preview    # shows a colored sample block for current folder
function project_color() {
	"$HOME/.local/bin/project_color" "$@"
}

function project_color_preview() {
	"$HOME/.local/bin/project_color" --preview "$@"
}

# Convenience alias so it feels like an app-style command.
alias project-color=project_color
alias project-colour=project_color
alias pc=project_color

alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias ......='cd ../../../../../'
alias .......='cd ../../../../../../'
