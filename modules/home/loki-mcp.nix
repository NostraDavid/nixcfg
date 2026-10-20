{
  config,
  lib,
  local,
  stable,
  unstable,
  ...
}: let
  nodeRepl = stable.writeShellScriptBin "opencode-mcp-node-repl" (builtins.readFile ./loki-node-repl.sh);
  python = stable.python3.withPackages (p: [p.tomlkit p.json5]);
  servers = {
    nixos.command = lib.getExe unstable.mcp-nixos;
    playwright = {
      command = lib.getExe unstable.playwright-mcp;
      args = ["--headless" "--isolated" "--browser" "chrome"];
    };
    chrome-devtools = {
      command = lib.getExe local.chrome-devtools-mcp;
      args = ["--headless" "--isolated" "--no-usage-statistics" "--no-performance-crux"];
    };
    dbhub = {
      command = lib.getExe local.dbhub;
      args = ["--transport" "stdio" "--config" "${config.xdg.configHome}/dbhub/local.toml"];
    };
    node_repl = {
      command = lib.getExe nodeRepl;
      startup_timeout_sec = 120;
    };
  };
  clientServers =
    servers
    // lib.genAttrs ["agent-memory" "headroom" "qartez"] (
      name: builtins.removeAttrs config.programs.pi.coding-agent.mcp.mcpServers.${name} ["description"]
    );
in {
  imports = [./development/agent-memory.nix ./development/headroom.nix];

  nixcfg.agentMemory.provider = lib.mkDefault "engrim";
  programs.pi.coding-agent.mcp.mcpServers = lib.mapAttrs (_: server:
    builtins.removeAttrs server ["startup_timeout_sec"])
  servers;

  home.packages = [local.dbhub nodeRepl];
  xdg.configFile."dbhub/local.toml".text = ''
    [[sources]]
    id = "local"
    description = "Local SQLite sandbox"
    dsn = "sqlite://${config.xdg.dataHome}/dbhub/local.sqlite"
  '';

  home.activation.lokiMcpClients = lib.hm.dag.entryAfter ["headroomClients" "linkGeneration"] ''
    $DRY_RUN_CMD ${stable.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg "${config.xdg.dataHome}/dbhub"}
    $DRY_RUN_CMD ${python}/bin/python ${./loki-mcp-clients.py} \
      ${lib.escapeShellArg config.home.homeDirectory} ${lib.escapeShellArg (builtins.toJSON clientServers)}
  '';
}
