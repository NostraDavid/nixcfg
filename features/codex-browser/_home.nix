# Codex native browser runtimes shared by Wodan, Frigg and Bragi.
{
  config,
  lib,
  local,
  stable,
  ...
}: let
  bin = "${config.home.homeDirectory}/.local/bin";
  codexNodeRepl = stable.writeShellScriptBin "codex-mcp-node-repl" ''
    export NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS=1000
    export NODE_REPL_NODE_MODULE_DIRS="${local.chatgpt}/lib/chatgpt/resources/cua_node/lib/node_modules"
    export NODE_REPL_NODE_PATH="${local.chatgpt}/lib/chatgpt/resources/cua_node/bin/node"
    export NODE_REPL_TRUSTED_CODE_PATHS="${config.home.homeDirectory}/.codex:${local.chatgpt}/lib/chatgpt/resources/cua_node/lib/node_modules"
    export CODEX_HOME=${lib.escapeShellArg "${config.home.homeDirectory}/.codex"}
    export BROWSER_USE_AVAILABLE_BACKENDS=chrome,iab,mcpapps
    export BROWSER_USE_TINYSKY_ENABLED=1
    export NODE_REPL_INSTRUCTIONS_USE_CASE_BROWSER="Control the in-app browser in conjunction with the Browser Plugin."
    export NODE_REPL_INSTRUCTIONS_USE_CASE_CHROME="Control the Chrome browser in conjunction with the Chrome Plugin. Prefer this method of controlling Chrome over alternatives (such as Computer Use) unless the user explicitly mentions an alternative."
    export BROWSER_USE_CODEX_APP_BUILD_FLAVOR=prod
    export BROWSER_USE_CODEX_APP_VERSION=${lib.escapeShellArg local.chatgpt.version}
    export NODE_REPL_TRUSTED_SERVICES=${lib.escapeShellArg (builtins.toJSON {browser = "${config.home.homeDirectory}/.codex/plugins/cache/openai-bundled/browser/${local.chatgpt.version}/scripts/browser-service.mjs";})}
    export CODEX_CLI_PATH="${local.chatgpt}/lib/chatgpt/resources/codex"
    exec "${local.chatgpt}/lib/chatgpt/resources/cua_node/bin/node_repl" "$@"
  '';
in {
  nixcfg.mcp.codexOverrides = {
    node_repl = {
      command = "${bin}/codex-mcp-node-repl";
      args = [];
      startup_timeout_sec = 120;
    };
    cua_repl = {
      command = "${bin}/cua-repl";
      enabled = false;
    };
  };
  home = {
    file = {
      ".local/bin/codex-mcp-node-repl".source = lib.getExe codexNodeRepl;
      ".local/bin/cua-repl".source = "${local.chatgpt}/lib/chatgpt/ChatGPT";
    };
    activation.codexBrowserRuntime = lib.hm.dag.entryBetween ["mcpClients"] ["linkGeneration"] ''
      for plugin in browser chrome; do
        cache="$HOME/.codex/plugins/cache/openai-bundled/$plugin/${local.chatgpt.version}"
        if [ -L "$cache" ]; then
          $DRY_RUN_CMD rm "$cache"
        fi
        if [ -d "$cache" ]; then
          $DRY_RUN_CMD ${stable.coreutils}/bin/chmod -R u+w "$cache"
        fi
        $DRY_RUN_CMD mkdir -p "$cache"
        # Replace cached files so running executables keep their original inode.
        $DRY_RUN_CMD ${stable.coreutils}/bin/cp -R --remove-destination --preserve=mode --no-preserve=ownership \
          "${local.chatgpt}/lib/chatgpt/resources/plugins/openai-bundled/plugins/$plugin/." "$cache/"
        $DRY_RUN_CMD ${stable.coreutils}/bin/chmod -R u+w "$cache"
      done

    '';
  };
}
