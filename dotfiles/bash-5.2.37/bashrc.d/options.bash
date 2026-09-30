# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f "$HOME/.bash_aliases" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bash_aliases"
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if has_builtin shopt && has_builtin complete && ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        # shellcheck source=/dev/null
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        # shellcheck source=/dev/null
        . /etc/bash_completion
    fi
fi

# Disable the bell
safe_bind "set bell-style visible"

# == shopts ==
# https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
safe_shopt -s autocd         # cd into folder without cd, so 'dotfiles' will cd into the folder
safe_shopt -s cdspell        # attempt spelling correcting on folders
safe_shopt -s direxpand      # expand a partial dir name
safe_shopt -s checkjobs      # stop shell from exit when there's jobs running
safe_shopt -s dirspell       # attempt spelling correcting on folders
safe_shopt -s expand_aliases # aliases are expanded
safe_shopt -s histappend     # append to the history file, don't overwrite it
safe_shopt -s histreedit     # lets your re-edit old executed command
safe_shopt -s histverify     # I'm confused.
safe_shopt -s hostcomplete   # performs completion when a word contains an '@'
safe_shopt -s globstar       # allow ** to recurse through directories
safe_shopt -s cmdhist        # save multiple-line command in single history entry
safe_shopt -u lithist        # multi-lines are saved with embedded newlines rather than semicolons; explictly unset
safe_shopt -s checkwinsize   # update LINES and COLUMNS to fit output
