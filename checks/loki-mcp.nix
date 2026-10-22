let
  flake = builtins.getFlake (toString ../.);
  lib = flake.inputs.nixpkgs.lib;
  home = flake.darwinConfigurations.loki.config.home-manager.users.david;
  wodan = flake.nixosConfigurations.wodan.config.home-manager.users.david;
  work = (flake.lib.mkLoki {username = "work";}).config.home-manager.users.work;
  names = ["agent-memory" "chrome-devtools" "dbhub" "headroom" "nixos" "playwright" "qartez"];
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
  realCodex = wodan.home.file.".local/bin/codex".source;
  realOpenCode = pkgs.opencode-v2;
  piBackup = pkgs.writeShellScript "pi-config-backup" wodan.home.activation.piConfigBackup.data;
  clientWrappers = let
    stub = name:
      pkgs.writeScriptBin name ''
        #!${pkgs.python3}/bin/python
        import json, os, pathlib, sys
        pathlib.Path(os.environ["MCP_CAPTURE"]).write_text(json.dumps({
            "args": sys.argv[1:],
            "config": os.environ.get("OPENCODE_CONFIG_CONTENT"),
            "path": os.environ["PATH"],
        }))
      '';
    launchers = profile: darwin: let
      module = import ../features/mcp/_home.nix {
        config = lib.recursiveUpdate profile {
          nixcfg.mcp.servers = lib.mapAttrs (name: server:
            lib.optionalAttrs (server ? command) {command = lib.getExe (stub name);})
          profile.nixcfg.mcp.servers;
        };
        inherit lib;
        stable = pkgs // {stdenv = pkgs.stdenv // {hostPlatform = pkgs.stdenv.hostPlatform // {isDarwin = darwin;};};};
        unstable = pkgs // {mcp-nixos = stub "nixos";};
        local = {
          codex = stub "codex";
        };
      };
    in
      module.config.home.file;
    linux = launchers wodan false;
    macos = launchers home true;
  in
    pkgs.linkFarm "mcp-client-wrapper-tests" (
      lib.concatMap (platform:
        map (name: {
          name = "${platform}-${name}";
          path =
            (
              if platform == "linux"
              then linux
              else macos
            ).".local/bin/${name}".source;
        }) (["codex"] ++ map (name: "mcp-${name}") names)) ["linux" "macos"]
    );
  python = pkgs.python3;
  servers = lib.getAttrs names home.nixcfg.mcp.servers;
  fixtureServers = {
    linux = lib.getAttrs names wodan.nixcfg.mcp.servers;
    macos = lib.getAttrs names home.nixcfg.mcp.servers;
  };
  profileServers = lib.mapAttrs (_: profile: lib.getAttrs names profile.nixcfg.mcp.servers) profiles;
  wodanScripts = pkgs.linkFarm "wodan-mcp-client-checks" (map (name: {
    inherit name;
    path = pkgs.writeShellScript name wodan.home.activation.${name}.data;
  }) ["headroomClients"]);
  wodanLaunchers = pkgs.linkFarm "wodan-mcp-launchers" (map (name: {
    inherit name;
    path = wodan.home.file.".local/bin/${name}".source;
  }) ["codex-mcp-node-repl" "mcp-node-repl" "opencode-mcp-chrome-devtools" "opencode-mcp-nixos" "opencode-mcp-playwright"]);
  checks = {
    workPackageSet = let
      loki = flake.darwinConfigurations.loki;
      module = import ../features/mcp/_home.nix {
        config = work;
        inherit lib;
        stable = loki.pkgs;
        unstable = flake.lib.unstableFor "aarch64-darwin";
        local = builtins.removeAttrs loki.config.home-manager.extraSpecialArgs.local ["opencode-v2"];
      };
    in
      assert toString module.config.home.file.".local/bin/opencode".source == lib.getExe (loki.pkgs.callPackage ../pkgs/opencode-v2 {}); true;
    chromium = assert lib.all (profile: builtins.length (builtins.filter (package: (package.pname or "") == "chromium") profile.home.packages) <= 1) allProfiles; true;
    nativeCodex = assert lib.all (profile: lib.all (name: profile.home.file ? ".local/bin/${name}") ["codex-mcp-node-repl" "cua-repl"] && profile.home.activation ? codexBrowserRuntime && profile.home.file.".local/bin/mcp-node-repl".source == profile.home.file.".local/bin/codex-mcp-node-repl".source) (builtins.attrValues nativeCodexProfiles); true;
    clients = assert lib.all (profile: profile.home.file ? ".local/bin/codex" && profile.home.file ? ".local/bin/opencode" && lib.all (name: profile.nixcfg.mcp.servers ? ${name}) names) allProfiles; true;
    piNoNodeRepl = assert lib.all (profile: !(profile.nixcfg.mcp.servers ? node_repl)) allProfiles; true;
    lokiNoNodeRepl = assert lib.all (profile: !(profile.nixcfg.mcp.servers ? node_repl) && !(profile.home.file ? ".local/bin/mcp-node-repl") && !(builtins.any (p: (p.name or "") == "mcp-node-repl") profile.home.packages)) [home work]; true;
    packages = assert lib.all (profile: lib.all (name: builtins.any (p: (p.pname or "") == name) profile.home.packages) packages) allProfiles; true;
    native = assert !(home.systemd.user.services ? ctx-history); assert !(builtins.any (p: builtins.elem (p.pname or "") ["ctx" "engram" "chatgpt" "blender-mcp"]) home.home.packages); true;
    database = assert lib.hasInfix "sqlite://${home.xdg.dataHome}/dbhub/local.sqlite" home.xdg.configFile."dbhub/local.toml".text; assert work.nixcfg.mcp.servers.dbhub.args == ["--transport" "stdio" "--config" "/Users/work/.config/dbhub/local.toml"]; true;
    browsers = assert home.nixcfg.mcp.servers.playwright.args == ["--headless" "--isolated" "--browser" "chrome"]; assert builtins.elem "--no-usage-statistics" home.nixcfg.mcp.servers.chrome-devtools.args; true;
    stableCommands = assert lib.all (profile:
      lib.all (name: let
        server = profile.nixcfg.mcp.servers.${name};
        relative = lib.removePrefix "${profile.home.homeDirectory}/" server.command;
      in
        lib.hasPrefix "${profile.home.homeDirectory}/.local/bin/" server.command && profile.home.file ? ${relative} && !(lib.hasInfix "/nix/store/" (builtins.toJSON server)))
      (builtins.attrNames (lib.filterAttrs (_: server: server ? command) profile.nixcfg.mcp.servers)))
    allProfiles; true;
    stablePi = assert lib.all (profile: lib.all (server: !(lib.hasInfix "/nix/store/" (builtins.toJSON server))) (builtins.attrValues profile.nixcfg.mcp.servers)) allProfiles; true;
  };
}
