{
  config,
  lib,
  local,
  stable,
  unstable,
  ...
}: let
  bin = "${config.home.homeDirectory}/.local/bin";
  darwin = stable.stdenv.hostPlatform.isDarwin;
  python = stable.python3.withPackages (p: [p.tomlkit p.json5]);
  nodeRepl = stable.writeShellScriptBin "opencode-mcp-node-repl" (
    if darwin
    then builtins.readFile ./loki-node-repl.sh
    else ''
      export NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS=1000
      export NODE_REPL_NODE_MODULE_DIRS="${local.chatgpt}/lib/chatgpt/resources/cua_node/lib/node_modules"
      export NODE_REPL_NODE_PATH="${local.chatgpt}/lib/chatgpt/resources/cua_node/bin/node"
      exec "${local.chatgpt}/lib/chatgpt/resources/cua_node/bin/node_repl" "$@"
    ''
  );
  browserArgs = ["--headless" "--isolated"] ++ lib.optionals (!darwin) ["--executable-path" "${bin}/chromium"];
  browserServers = {
    nixos.command = "${bin}/mcp-nixos";
    playwright = {
      command = "${bin}/playwright-mcp";
      args = browserArgs ++ lib.optionals darwin ["--browser" "chrome"];
    };
    chrome-devtools = {
      command = "${bin}/chrome-devtools-mcp";
      args = browserArgs ++ ["--no-usage-statistics" "--no-performance-crux"];
    };
  };
  wrappers = lib.mapAttrsToList (name: server:
    stable.writeShellScriptBin "opencode-mcp-${name}" ''
      exec ${lib.escapeShellArg server.command} ${lib.escapeShellArgs (server.args or [])} "$@"
    '')
  browserServers;
  servers =
    browserServers
    // {
      dbhub = {
        command = "${bin}/dbhub";
        args = ["--transport" "stdio" "--config" "${config.xdg.configHome}/dbhub/local.toml"];
      };
      node_repl = {
        command = "${bin}/opencode-mcp-node-repl";
        startup_timeout_sec = 120;
      };
    };
  clientServers =
    servers
    // lib.genAttrs ["agent-memory" "headroom" "qartez"] (
      name: builtins.removeAttrs config.programs.pi.coding-agent.mcp.mcpServers.${name} ["description"]
    );
in {
  options.nixcfg.mcp.codexOverrides = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = {};
    description = "Client-specific MCP settings, such as Codex's native browser runtime.";
  };
  config = {
    nixcfg.agentMemory.provider = lib.mkDefault "engrim";
    programs.pi.coding-agent.mcp.mcpServers = lib.mapAttrs (_: server:
      builtins.removeAttrs server ["startup_timeout_sec"])
    servers;
    home = {
      sessionPath = [bin];
      packages =
        [local.dbhub local.chrome-devtools-mcp unstable.mcp-nixos unstable.playwright-mcp nodeRepl]
        ++ wrappers;
      file =
        {
          ".local/bin/mcp-nixos".source = lib.getExe unstable.mcp-nixos;
          ".local/bin/playwright-mcp".source = lib.getExe unstable.playwright-mcp;
          ".local/bin/chrome-devtools-mcp".source = lib.getExe local.chrome-devtools-mcp;
          ".local/bin/dbhub".source = lib.getExe local.dbhub;
          ".local/bin/opencode-mcp-node-repl".source = lib.getExe nodeRepl;
        }
        // lib.optionalAttrs (!darwin) {".local/bin/chromium".source = lib.getExe stable.chromium;}
        // builtins.listToAttrs (map (package: lib.nameValuePair ".local/bin/${lib.getName package}" {source = lib.getExe package;}) wrappers);
      activation = {
        dbhubLocalDatabase = lib.hm.dag.entryAfter ["writeBoundary"] ''
          $DRY_RUN_CMD ${stable.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg "${config.xdg.dataHome}/dbhub"}
        '';
        mcpClients = lib.hm.dag.entryAfter ["headroomClients" "linkGeneration" "dbhubLocalDatabase"] ''
          $DRY_RUN_CMD ${python}/bin/python ${./mcp-clients.py} \
            ${lib.escapeShellArg config.home.homeDirectory} \
            ${lib.escapeShellArg (builtins.toJSON clientServers)} \
            ${lib.escapeShellArg (builtins.toJSON ({openaiDeveloperDocs.url = config.programs.pi.coding-agent.mcp.mcpServers.openaiDeveloperDocs.url;} // config.nixcfg.mcp.codexOverrides))}
        '';
      };
    };
    xdg.configFile."dbhub/local.toml".text = ''
      [[sources]]
      id = "local"
      description = "Local SQLite sandbox"
      dsn = "sqlite://${config.xdg.dataHome}/dbhub/local.sqlite"
    '';
  };
}
