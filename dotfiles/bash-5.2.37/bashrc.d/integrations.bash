# == tmux addon ==
tmux-git-autofetch() { ("$HOME/.tmux/plugins/tmux-git-autofetch/git-autofetch.tmux" --current &) }

# == ensure ctrl-d doesn't fuck up tmux ==
if [[ -n "$TMUX" ]]; then
    # Ignore EOF (Ctrl+D) in tmux sessions
    set -o ignoreeof
fi

# == direnv ==
eval "$(direnv hook bash)"

# == Worktrunk worktree switching ==
if command -v wt >/dev/null 2>&1; then
    eval "$(wt config shell init bash)"
fi

# == starship prompt ==
if [ -n "$use_starship_prompt" ]; then
    eval "$(starship init bash)"
fi

# == fzf-bash integration via ctrl-r ==
if [ -n "${XDG_DATA_DIRS-}" ]; then
    for dir in ${XDG_DATA_DIRS//:/ }; do
        if has_builtin complete && [ -f "$dir/fzf/completion.bash" ]; then
            # shellcheck source=/dev/null
            source "$dir/fzf/completion.bash"
        fi
        if has_builtin bind && [ -f "$dir/fzf/key-bindings.bash" ]; then
            # shellcheck source=/dev/null
            source "$dir/fzf/key-bindings.bash"
        fi
    done
fi

# Work settings can live in the separate work repository.
if [ -f "$HOME/.bashrc.work" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc.work"
fi

# load a non-tracked local file (if it exists)
if [ -f "$HOME/.bashrc.local" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc.local"
fi

# Keep history syncing last so prompt integrations can safely extend
# PROMPT_COMMAND without clobbering each other.
append_prompt_command reset_terminal_mouse 'history -a' 'history -n'
