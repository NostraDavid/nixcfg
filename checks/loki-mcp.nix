let
  flake = builtins.getFlake (toString ../.);
  lib = flake.inputs.nixpkgs.lib;
  home = flake.darwinConfigurations.loki.config.home-manager.users.david;
  wodan = flake.nixosConfigurations.wodan.config.home-manager.users.david;
  work = (flake.lib.mkLoki {username = "work";}).config.home-manager.users.work;
  names = ["agent-memory" "chrome-devtools" "dbhub" "headroom" "nixos" "node_repl" "playwright" "qartez"];
  packages = ["engrim" "headroom-ai" "dbhub" "chrome-devtools-mcp" "playwright-mcp" "mcp-nixos" "qartez"];
  pkgs = flake.legacyPackages.x86_64-linux;
  profiles =
    (lib.mapAttrs (_: host: host.config.home-manager.users.david)
      (lib.filterAttrs (_: host: host.config ? home-manager.users.david) flake.nixosConfigurations))
    // (lib.mapAttrs (_: host: host.config.home-manager.users.david) flake.darwinConfigurations)
    // (lib.mapAttrs (_: host: host.config) flake.homeConfigurations);
  allProfiles = builtins.attrValues profiles ++ [work];
  nativeCodexProfiles = lib.getAttrs ["wodan" "frigg" "bragi"] profiles;
in {
  python = pkgs.python3.withPackages (p: [p.tomlkit p.json5]);
  servers = lib.getAttrs names home.programs.pi.coding-agent.mcp.mcpServers;
  profileServers = lib.mapAttrs (_: profile: lib.getAttrs names profile.programs.pi.coding-agent.mcp.mcpServers) profiles;
  wodanScripts = pkgs.linkFarm "wodan-mcp-client-checks" (map (name: {
    inherit name;
    path = pkgs.writeShellScript name wodan.home.activation.${name}.data;
  }) ["headroomClients" "mcpClients"]);
  wodanLaunchers = pkgs.linkFarm "wodan-mcp-launchers" (map (name: {
    inherit name;
    path = wodan.home.file.".local/bin/${name}".source;
  }) ["codex-mcp-node-repl" "opencode-mcp-node-repl" "opencode-mcp-chrome-devtools" "opencode-mcp-nixos" "opencode-mcp-playwright"]);
  checks = {
    chromium = assert lib.all (profile: builtins.length (builtins.filter (package: (package.pname or "") == "chromium") profile.home.packages) <= 1) allProfiles; true;
    nativeCodex = assert lib.all (profile: lib.all (name: profile.home.file ? ".local/bin/${name}") ["codex-mcp-node-repl" "cua-repl"] && profile.home.activation ? codexBrowserRuntime && profile.nixcfg.mcp.codexOverrides.node_repl.command == "${profile.home.homeDirectory}/.local/bin/codex-mcp-node-repl" && !profile.nixcfg.mcp.codexOverrides.cua_repl.enabled) (builtins.attrValues nativeCodexProfiles); true;
    clients = assert lib.all (profile: profile.home.activation ? mcpClients && lib.all (name: profile.programs.pi.coding-agent.mcp.mcpServers ? ${name}) names) allProfiles; true;
    packages = assert lib.all (profile: lib.all (name: builtins.any (p: (p.pname or "") == name) profile.home.packages) packages) allProfiles; true;
    native = assert !(home.systemd.user.services ? ctx-history); assert !(builtins.any (p: builtins.elem (p.pname or "") ["ctx" "engram" "chatgpt" "blender-mcp"]) home.home.packages); true;
    database = assert lib.hasInfix "sqlite://${home.xdg.dataHome}/dbhub/local.sqlite" home.xdg.configFile."dbhub/local.toml".text; assert work.programs.pi.coding-agent.mcp.mcpServers.dbhub.args == ["--transport" "stdio" "--config" "/Users/work/.config/dbhub/local.toml"]; true;
    browsers = assert home.programs.pi.coding-agent.mcp.mcpServers.playwright.args == ["--headless" "--isolated" "--browser" "chrome"]; assert builtins.elem "--no-usage-statistics" home.programs.pi.coding-agent.mcp.mcpServers.chrome-devtools.args; true;
    stableCommands = assert lib.all (profile:
      lib.all (name: let
        server = profile.programs.pi.coding-agent.mcp.mcpServers.${name};
        relative = lib.removePrefix "${profile.home.homeDirectory}/" server.command;
      in
        lib.hasPrefix "${profile.home.homeDirectory}/.local/bin/" server.command && profile.home.file ? ${relative} && !(lib.hasInfix "/nix/store/" (builtins.toJSON server)))
      (builtins.attrNames (lib.filterAttrs (_: server: server ? command) profile.programs.pi.coding-agent.mcp.mcpServers)))
    allProfiles; true;
    stablePi = assert lib.all (profile: lib.all (server: !(lib.hasInfix "/nix/store/" (builtins.toJSON server))) (builtins.attrValues profile.programs.pi.coding-agent.mcp.mcpServers)) allProfiles; true;
  };
}
