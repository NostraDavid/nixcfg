# uv rejects an empty value inherited from terminal environments.
[[ -n ${UV_PYTHON_DOWNLOADS-} ]] || unset UV_PYTHON_DOWNLOADS

# PATH helpers (avoid duplicates when shells inherit an existing PATH).
path_prepend() {
    local dir
    for dir in "$@"; do
        [[ -n "$dir" ]] || continue
        [[ -d "$dir" ]] || continue
        case ":$PATH:" in
        *":$dir:"*) ;;
        *) PATH="$dir${PATH:+:$PATH}" ;;
        esac
    done
}

path_append() {
    local dir
    for dir in "$@"; do
        [[ -n "$dir" ]] || continue
        [[ -d "$dir" ]] || continue
        case ":$PATH:" in
        *":$dir:"*) ;;
        *) PATH="${PATH:+$PATH:}$dir" ;;
        esac
    done
}

path_remove() {
    local remove_dir current_dir new_path
    local -a path_parts
    for remove_dir in "$@"; do
        [[ -n "$remove_dir" ]] || continue
        new_path=""
        IFS=: read -r -a path_parts <<<"$PATH"
        for current_dir in "${path_parts[@]}"; do
            [[ -n "$current_dir" ]] || continue
            [[ "$current_dir" == "$remove_dir" ]] && continue
            new_path="${new_path:+$new_path:}$current_dir"
        done
        PATH="$new_path"
    done
}

append_prompt_command() {
    local cmd existing
    for cmd in "$@"; do
        [[ -n "$cmd" ]] || continue

        if declare -p PROMPT_COMMAND >/dev/null 2>&1 && [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a"* ]]; then
            for existing in "${PROMPT_COMMAND[@]}"; do
                [[ "$existing" == "$cmd" ]] && continue 2
            done
            PROMPT_COMMAND+=("$cmd")
        elif [[ -n "${PROMPT_COMMAND:-}" ]]; then
            [[ "$PROMPT_COMMAND" == *"$cmd"* ]] && continue
            PROMPT_COMMAND="${PROMPT_COMMAND%;}; $cmd"
        else
            PROMPT_COMMAND="$cmd"
        fi
    done
}

# User specific environment. Remove inherited copies before establishing a
# deterministic order with ~/.local/bin ahead of ~/bin.
path_remove "$HOME/.local/bin" "$HOME/bin"
path_prepend "$HOME/bin" "$HOME/.local/bin"
export PATH

if [[ $(uname -s) == Linux ]]; then
    # Flatpak desktop entries and the Linux locale.
    export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
fi

# make ls output iso8601
export TIME_STYLE=long-iso

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=
