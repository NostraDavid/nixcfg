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
  nodeRepl = stable.writeShellScriptBin "mcp-node-repl" ''
    export NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS=1000
    export NODE_REPL_NODE_MODULE_DIRS="${local.chatgpt}/lib/chatgpt/resources/cua_node/lib/node_modules"
    export NODE_REPL_NODE_PATH="${local.chatgpt}/lib/chatgpt/resources/cua_node/bin/node"
    exec "${local.chatgpt}/lib/chatgpt/resources/cua_node/bin/node_repl" "$@"
  '';
  browserArgs =
    [
      "--headless"
      "--isolated"
    ]
    ++ lib.optionals (!darwin) [
      "--executable-path"
      "${bin}/chromium"
    ];
  browserServers = {
    # nixos.command = "${bin}/mcp-nixos"; # Disabled until FastMCP builds.
    playwright = {
      command = "${bin}/playwright-mcp";
      args =
        browserArgs
        ++ lib.optionals darwin [
          "--browser"
          "chrome"
        ];
    };
    chrome-devtools = {
      command = "${bin}/chrome-devtools-mcp";
      args =
        browserArgs
        ++ [
          "--no-usage-statistics"
          "--no-performance-crux"
        ];
    };
  };

  servers =
    browserServers
    // {
      dbhub = {
        command = "${bin}/dbhub";
        args = [
          "--transport"
          "stdio"
          "--config"
          "${config.xdg.configHome}/dbhub/local.toml"
        ];
      };
    };
  localServers = lib.filterAttrs (_: server: server ? command) config.nixcfg.mcp.servers;
  wrappers = lib.mapAttrsToList (name: server:
    stable.writeShellScriptBin "mcp-${name}" ''
      exec ${lib.escapeShellArg server.command} ${lib.escapeShellArgs (server.args or [])} "$@"
    '')
  (builtins.removeAttrs localServers ["nixos"]);
  codex = stable.writeShellScript "codex" ''
    export PATH="$HOME/.local/bin:$PATH"
    exec ${lib.getExe local.codex} \
      ${lib.optionalString darwin "--config mcp_servers.node_repl.enabled=false"} \
      "$@"
  '';
in {
  options.nixcfg.mcp = {
    servers = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {};
      description = "Shared MCP server commands and arguments for client launchers.";
    };
  };
  config = {
    nixcfg = {
      agentMemory.provider = lib.mkDefault "engrim";
      mcp = {
        servers = lib.mapAttrs (_: server:
          builtins.removeAttrs server [
            "startup_timeout_sec"
          ])
        servers;
      };
    };
    home = {
      sessionPath = [
        bin
      ];
      packages =
        [
          local.chrome-devtools-mcp
          local.dbhub
          # stable.mcp-nixos # Disabled: FastMCP's stateful proxy tests fail.
          unstable.playwright-mcp
        ]
        ++ lib.optional (!darwin) nodeRepl
        ++ wrappers;
      file =
        {
          ".local/bin/codex".source = codex;
          ".local/bin/opencode".source = lib.getExe (stable.callPackage ../../pkgs/opencode-v2 {});
          # ".local/bin/mcp-nixos".source = lib.getExe stable.mcp-nixos;
          ".local/bin/playwright-mcp".source = lib.getExe unstable.playwright-mcp;
          ".local/bin/chrome-devtools-mcp".source = lib.getExe local.chrome-devtools-mcp;
          ".local/bin/dbhub".source = lib.getExe local.dbhub;
        }
        // lib.optionalAttrs (!darwin) {
          ".local/bin/chromium".source = lib.getExe stable.chromium;
          ".local/bin/mcp-node-repl".source = lib.getExe nodeRepl;
        }
        // builtins.listToAttrs (map (package: lib.nameValuePair ".local/bin/${lib.getName package}" {source = lib.getExe package;}) wrappers)
        # Work repositories also use the existing browser launcher names.
        // builtins.listToAttrs (map (name:
          lib.nameValuePair ".local/bin/opencode-mcp-${name}" {
            source = config.home.file.".local/bin/mcp-${name}".source;
          }) ["chrome-devtools" "playwright"]);
      activation = {
        dbhubLocalDatabase =
          lib.hm.dag.entryAfter [
            "writeBoundary"
          ] ''
            $DRY_RUN_CMD ${stable.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg "${config.xdg.dataHome}/dbhub"}
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
