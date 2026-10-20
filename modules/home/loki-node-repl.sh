#!/usr/bin/env bash
set -euo pipefail

for app in /Applications/Codex.app /Applications/ChatGPT.app "$HOME/Applications/Codex.app" "$HOME/Applications/ChatGPT.app"; do
    runtime="$app/Contents/Resources/cua_node"
    if [[ -x "$runtime/bin/node_repl" && -x "$runtime/bin/node" ]]; then
        export NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS=1000
        export NODE_REPL_NODE_MODULE_DIRS="$runtime/lib/node_modules"
        export NODE_REPL_NODE_PATH="$runtime/bin/node"
        exec "$runtime/bin/node_repl" "$@"
    fi
done

echo 'Node REPL requires Codex.app or ChatGPT.app with cua_node in /Applications or ~/Applications.' >&2
exit 1
