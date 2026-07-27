{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
  inherit (builtins) attrNames filter listToAttrs map readDir;
  localPackageNames = let
    entries = readDir ../../pkgs;
  in
    filter (name: entries.${name} == "directory") (attrNames entries);
  local =
    listToAttrs
    (map (name: {
        inherit name;
        value = pkgs.${name};
      })
      localPackageNames);
  agentMcpServers = {
    headroom = {
      command = lib.getExe local.headroom;
      args = ["mcp" "serve"];
    };
    serena = {
      command = lib.getExe local.serena;
      args = ["start-mcp-server" "--context" "ide-assistant"];
    };
    engram = {
      command = lib.getExe local.engram;
      args = ["mcp"];
    };
  };
  claudeMcpServers = builtins.toJSON agentMcpServers;
  geminiMcpServers = builtins.toJSON (
    builtins.mapAttrs (_: server: server // {trust = true;}) agentMcpServers
  );
  copilotMcpServers = builtins.toJSON (
    builtins.mapAttrs (_: server:
      server
      // {
        type = "local";
        tools = ["*"];
      })
    agentMcpServers
  );
  piExe = lib.getExe config.programs.pi.coding-agent.finalPackage;
in {
  programs.pi.coding-agent.enable = true;

  xdg.desktopEntries.code = {
    name = "Visual Studio Code";
    genericName = "Text Editor";
    comment = "Code Editing. Redefined.";
    exec = "${config.home.homeDirectory}/.local/bin/ide --no-picker %F";
    icon = "vscode";
    terminal = false;
    type = "Application";
    categories = ["Utility" "TextEditor" "Development" "IDE"];
    startupNotify = true;
    settings = {
      StartupWMClass = "Code";
      Actions = "new-empty-window";
      Keywords = "vscode";
    };
    actions.new-empty-window = {
      name = "New Empty Window";
      icon = "vscode";
      exec = "${lib.getExe local.vscode} --new-window %F";
    };
  };

  home = {
    packages = with pkgs; [
      # Language runtimes and additional development applications.
      jdk17 # openjdk for nvim-lsp-java
      zed-editor # vscode alternative
      gofumpt # gofmt alternative; useful for dprint

      # unstable
      # unstable.gemini-cli # llm agent
      # unstable.antigravity-cli # llm agent
      # unstable.github-copilot-cli
      unstable.dprint # Extensible code formatter; prettier replacement
      unstable.oxlint # js linter
      unstable.fastfetch # neofetch alternative
      unstable.zigfetch # neofetch alternative
      unstable.devenv # Development environment manager | using unstable for 2.x
      # unstable.codex # lln agent
      unstable.witr # Why is this running?
      unstable.zsv # CSV viewer and slicer
      unstable.opencode # llm agent
      unstable.claude-code # llm agent
      unstable.ctx7 # Context7 CLI - Manage AI coding skills and documentation context
      unstable.python313 # Runtime for executable agent skill helpers

      # local
      freetype # font-rendering library, for Whatpulse
      libpcap # for Whatpulse
      local.jpegli
      local.fixit
      local.mdschema
      local.whatpulse
      local.yafc
      local.xdgctl
      local.vscode
      local.jsongrep # JSONPath-inspired query language over JSON documents
      local.austin # CPython frame stack sampler
      local.dpaint-js
      local.doctok
      local.gigatoken
      local.tiktoken
      local.ptk
      local.photogimp # Photoshop-like defaults for GIMP
      local.hermes-agent
      local.github-copilot-cli
      local.snip # CLI proxy, to reduce token usage for LLMs
      local.rtk # CLI proxy, to reduce token usage for LLMs
      local.headroom # Context compression proxy for AI agents
      local.serena # Symbol-aware code navigation and editing MCP server
      local.probe # AST-aware semantic code search and MCP server
      local.engram # Persistent memory and MCP server for coding agents
      local.beads # Dependency-aware task handoff between coding agents
      local.codealmanac # Local codebase wiki for AI coding agents
      local.skillkit # Local codebase wiki for AI coding agents
    ];

    activation = {
      piTensorx = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if ! $DRY_RUN_CMD ${piExe} list 2>/dev/null \
          | ${lib.getExe pkgs.gnugrep} -F '@czottmann/pi-tensorx' >/dev/null 2>&1; then
          if ! $DRY_RUN_CMD ${piExe} install npm:@czottmann/pi-tensorx; then
            echo "warning: failed to install Pi extension @czottmann/pi-tensorx" >&2
          fi
        fi

        if ! $DRY_RUN_CMD ${piExe} list 2>/dev/null \
          | ${lib.getExe pkgs.gnugrep} -F 'pi-mcp-adapter' >/dev/null 2>&1; then
          if ! $DRY_RUN_CMD ${piExe} install npm:pi-mcp-adapter; then
            echo "warning: failed to install Pi extension pi-mcp-adapter" >&2
          fi
        fi
      '';

      dprintVscodeExtension = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if ! $DRY_RUN_CMD ${lib.getExe local.vscode} --list-extensions 2>/dev/null \
          | ${lib.getExe pkgs.gnugrep} -Fx 'dprint.dprint' >/dev/null 2>&1; then
          if ! $DRY_RUN_CMD ${lib.getExe local.vscode} \
            --install-extension dprint.dprint; then
            echo "warning: failed to install VS Code extension dprint.dprint" >&2
          fi
        fi
      '';

      agentMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if [ ! -f "${config.home.homeDirectory}/.serena/serena_config.yml" ]; then
          $DRY_RUN_CMD ${lib.getExe local.serena} init
        fi

        update_mcp_json() {
          config_file="$1"
          servers_json="$2"
          config_dir="$(${pkgs.coreutils}/bin/dirname "$config_file")"
          temporary_file="$(${pkgs.coreutils}/bin/mktemp)"

          if [ -f "$config_file" ]; then
            ${lib.getExe pkgs.jq} --argjson servers "$servers_json" \
              '.mcpServers = (((.mcpServers // {}) | del(."lean-ctx")) + $servers)' \
              "$config_file" >"$temporary_file"
          else
            ${lib.getExe pkgs.jq} --null-input --argjson servers "$servers_json" \
              '{mcpServers: $servers}' >"$temporary_file"
          fi

          if [ ! -f "$config_file" ] \
            || ! ${pkgs.diffutils}/bin/cmp --silent "$temporary_file" "$config_file"; then
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$config_dir"
            if [ -f "$config_file" ]; then
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 \
                "$config_file" "$config_file.hm-mcp-backup"
            fi
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 "$temporary_file" "$config_file"
          fi
          ${pkgs.coreutils}/bin/rm -f "$temporary_file"
        }

        update_mcp_json \
          "${config.home.homeDirectory}/.claude.json" \
          '${claudeMcpServers}'
        update_mcp_json \
          "${config.home.homeDirectory}/.gemini/settings.json" \
          '${geminiMcpServers}'
        update_mcp_json \
          "${config.home.homeDirectory}/.copilot/mcp-config.json" \
          '${copilotMcpServers}'
        update_mcp_json \
          "${config.home.homeDirectory}/.config/mcp/mcp.json" \
          '${claudeMcpServers}'

        codex_executable=${lib.getExe pkgs.codex}
        $DRY_RUN_CMD "$codex_executable" mcp remove lean-ctx >/dev/null 2>&1 || true

        $DRY_RUN_CMD "$codex_executable" mcp remove headroom >/dev/null 2>&1 || true
        $DRY_RUN_CMD "$codex_executable" mcp add headroom -- \
          ${lib.getExe local.headroom} mcp serve

        $DRY_RUN_CMD "$codex_executable" mcp remove serena >/dev/null 2>&1 || true
        $DRY_RUN_CMD "$codex_executable" mcp add serena -- \
          ${lib.getExe local.serena} start-mcp-server --context codex

        $DRY_RUN_CMD "$codex_executable" mcp remove engram >/dev/null 2>&1 || true
        $DRY_RUN_CMD "$codex_executable" mcp add engram -- \
          ${lib.getExe local.engram} mcp
      '';
    };
  };
}
