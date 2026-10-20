let
  flake = builtins.getFlake (toString ../.);
  lib = flake.inputs.nixpkgs.lib;
  home = flake.darwinConfigurations.loki.config.home-manager.users.david;
  work = (flake.lib.mkLoki {username = "work";}).config.home-manager.users.work;
  names = ["agent-memory" "chrome-devtools" "dbhub" "headroom" "nixos" "node_repl" "playwright" "qartez"];
  packages = ["engrim" "headroom-ai" "dbhub" "chrome-devtools-mcp" "playwright-mcp" "mcp-nixos" "qartez"];
  pkgs = flake.legacyPackages.x86_64-linux;
in {
  python = pkgs.python3.withPackages (p: [p.tomlkit p.json5]);
  servers = lib.getAttrs names home.programs.pi.coding-agent.mcp.mcpServers;
  checks = {
    clients = assert home.home.activation ? lokiMcpClients; assert lib.all (name: home.programs.pi.coding-agent.mcp.mcpServers ? ${name}) names; true;
    packages = assert lib.all (name: builtins.any (p: (p.pname or "") == name) home.home.packages) packages; true;
    native = assert !(home.systemd.user.services ? ctx-history); assert !(builtins.any (p: builtins.elem (p.pname or "") ["ctx" "engram" "chatgpt" "blender-mcp"]) home.home.packages); true;
    database = assert lib.hasInfix "sqlite://${home.xdg.dataHome}/dbhub/local.sqlite" home.xdg.configFile."dbhub/local.toml".text; assert work.programs.pi.coding-agent.mcp.mcpServers.dbhub.args == ["--transport" "stdio" "--config" "/Users/work/.config/dbhub/local.toml"]; true;
    browsers = assert home.programs.pi.coding-agent.mcp.mcpServers.playwright.args == ["--headless" "--isolated" "--browser" "chrome"]; assert builtins.elem "--no-usage-statistics" home.programs.pi.coding-agent.mcp.mcpServers.chrome-devtools.args; true;
  };
}
