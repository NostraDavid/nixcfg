{
  config,
  lib,
  local,
  stable,
  unstable,
  ...
}: let
  agentExecutables = {
    engram = "${config.home.profileDirectory}/bin/engram";
    headroom = "${config.home.profileDirectory}/bin/headroom";
    leanCtx = "${config.home.profileDirectory}/bin/lean-ctx";
    qartez = "${config.home.profileDirectory}/bin/qartez";
  };
  agentMcpServers = {
    qartez = {
      command = agentExecutables.qartez;
      args = [];
    };
    engram = {
      command = agentExecutables.engram;
      args = ["mcp"];
    };
    lean-ctx = {
      command = agentExecutables.leanCtx;
      args = [];
    };
  };
  claudeMcpServers = builtins.toJSON agentMcpServers;
  copilotMcpServers = builtins.toJSON (
    builtins.mapAttrs (_: server:
      server
      // {
        type = "local";
        tools = ["*"];
      })
    agentMcpServers
  );
  headroomLeanCtxAddonManifest = stable.writeText "lean-ctx-headroom-addon.toml" ''
    [addon]
    name = "headroom"
    display_name = "Headroom"
    version = "${local.headroom.version}"
    description = "Reversible context compression for tool outputs, logs, files, and RAG chunks"
    author = "Headroom Labs"
    homepage = "https://github.com/chopratejas/headroom"
    license = "Apache-2.0"
    categories = ["compression"]
    integration = "compression"
    min_lean_ctx = "3.9.0"

    [mcp]
    transport = "stdio"
    command = "${agentExecutables.headroom}"
    args = ["mcp", "serve"]

    [capabilities]
    network = "full"
    filesystem = "read_write"
    env = []
    exec = "none"
  '';
in {
  programs.pi.coding-agent = {
    enable = true;
    settings = builtins.fromJSON (
      builtins.readFile ../../dotfiles/pi/.pi/agent/settings.json
    );
  };

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
    packages = [
      local.austin # CPython frame stack sampler
      local.codex # llm agent
      local.codex-security # Codex Security CLI
      local.cool-retro-term # terminal emulator with retro style
      local.dpaint-js # DPaint written in JS
      local.engram # Persistent memory and MCP server for coding agents
      local.fixit # fix command in case you mess up a command
      local.gigatoken # Fast tokenization for OpenAI models
      local.headroom # Compression addon available only through the LeanCTX gateway
      local.hermes-agent # LLM agent for desktop
      local.jsongrep # JSONPath-inspired query language over JSON documents
      local.lean-ctx # Context engineering layer shared by coding agents
      local.mdschema # A declarative schema-based Markdown validator
      local.photogimp # Photoshop-like defaults for GIMP
      local.ptk # python-token-killer
      local.qartez # Semantic code intelligence MCP server
      local.tiktoken # Tokenizer for OpenAI models
      local.vscode
      local.xdgctl # TUI for managing XDG default applications
      local.yafc # Yet Another Ftp Client
      stable.gofumpt # gofmt alternative; useful for dprint
      stable.openjdk25 # openjdk for nvim-lsp-java
      stable.zed-editor # vscode alternative
      unstable.claude-code # llm agent
      unstable.ctx7 # Context7 CLI - Manage AI coding skills and documentation context
      unstable.dprint # Extensible code formatter; prettier replacement
      unstable.fastfetch # neofetch alternative
      unstable.github-copilot-cli
      unstable.mistral-vibe # Mistral coding agent
      unstable.opencode # llm agent
      unstable.opencode-desktop # llm agent for desktop
      unstable.oxlint # js linter
      unstable.python313 # Runtime for executable agent skill helpers
      unstable.witr # Why is this running?
      unstable.zigfetch # neofetch alternative
    ];

    activation = {
      dprintVscodeExtension = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if ! $DRY_RUN_CMD ${lib.getExe local.vscode} --list-extensions 2>/dev/null \
            | ${lib.getExe stable.gnugrep} -Fx 'dprint.dprint' >/dev/null 2>&1; then
          if ! $DRY_RUN_CMD ${lib.getExe local.vscode} \
            --install-extension dprint.dprint; then
            echo "warning: failed to install VS Code extension dprint.dprint" >&2
          fi
        fi
      '';

      agentMcpServers = lib.hm.dag.entryAfter ["writeBoundary"] ''
        update_mcp_json() {
          config_file="$1"
          servers_json="$2"
          config_dir="$(${stable.coreutils}/bin/dirname "$config_file")"
          temporary_file="$(${stable.coreutils}/bin/mktemp)"

          if [ -f "$config_file" ]; then
            ${lib.getExe stable.jq} --argjson servers "$servers_json" \
              '.mcpServers = (((.mcpServers // {}) | del(.headroom, ."lean-ctx", .serena)) + $servers)' \
              "$config_file" >"$temporary_file"
          else
            ${lib.getExe stable.jq} --null-input --argjson servers "$servers_json" \
              '{mcpServers: $servers}' >"$temporary_file"
          fi

          if [ ! -f "$config_file" ] \
            || ! ${stable.diffutils}/bin/cmp --silent "$temporary_file" "$config_file"; then
            $DRY_RUN_CMD ${stable.coreutils}/bin/mkdir -p "$config_dir"
            if [ -f "$config_file" ]; then
              $DRY_RUN_CMD ${stable.coreutils}/bin/install -m 0600 \
                "$config_file" "$config_file.hm-mcp-backup"
            fi
            $DRY_RUN_CMD ${stable.coreutils}/bin/install -m 0600 "$temporary_file" "$config_file"
          fi
          ${stable.coreutils}/bin/rm -f "$temporary_file"
        }

        update_mcp_json \
          "${config.home.homeDirectory}/.claude.json" \
          '${claudeMcpServers}'
        update_mcp_json \
          "${config.home.homeDirectory}/.copilot/mcp-config.json" \
          '${copilotMcpServers}'
        update_mcp_json \
          "${config.home.homeDirectory}/.config/mcp/mcp.json" \
          '${claudeMcpServers}'

        update_structured_config() {
          config_file="$1"
          input_format="$2"
          output_format="$3"
          expression="$4"
          config_dir="$(${stable.coreutils}/bin/dirname "$config_file")"
          temporary_file="$(${stable.coreutils}/bin/mktemp)"

          if [ -f "$config_file" ]; then
            ${lib.getExe stable.yq-go} -p "$input_format" -o "$output_format" \
              "$expression" "$config_file" >"$temporary_file"
          else
            ${lib.getExe stable.yq-go} --null-input -p "$input_format" -o "$output_format" \
              "$expression" >"$temporary_file"
          fi

          if [ ! -f "$config_file" ] \
            || ! ${stable.diffutils}/bin/cmp --silent "$temporary_file" "$config_file"; then
            $DRY_RUN_CMD ${stable.coreutils}/bin/mkdir -p "$config_dir"
            if [ -f "$config_file" ]; then
              $DRY_RUN_CMD ${stable.coreutils}/bin/install -m 0600 \
                "$config_file" "$config_file.hm-lean-ctx-backup"
            fi
            $DRY_RUN_CMD ${stable.coreutils}/bin/install -m 0600 "$temporary_file" "$config_file"
          fi
          ${stable.coreutils}/bin/rm -f "$temporary_file"
        }

        update_structured_config \
          "${config.home.homeDirectory}/.config/lean-ctx/config.toml" toml toml \
          '.hook_binary = "${agentExecutables.leanCtx}"'
        update_structured_config \
          "${config.home.homeDirectory}/.hermes/config.yaml" yaml yaml \
          '.mcp_servers = ((.mcp_servers // {}) + {"engram": {"command": "${agentExecutables.engram}", "args": ["mcp"]}, "lean-ctx": {"command": "${agentExecutables.leanCtx}"}, "qartez": {"command": "${agentExecutables.qartez}"}})'
        update_structured_config \
          "${config.home.homeDirectory}/.vibe/config.toml" toml toml \
          '.mcp_servers = (((.mcp_servers // []) | map(select(.name != "engram" and .name != "lean-ctx" and .name != "qartez"))) + [{"name": "engram", "transport": "stdio", "command": "${agentExecutables.engram}", "args": ["mcp"]}, {"name": "lean-ctx", "transport": "stdio", "command": "${agentExecutables.leanCtx}", "args": ["serve"]}, {"name": "qartez", "transport": "stdio", "command": "${agentExecutables.qartez}", "args": []}])'
        update_structured_config \
          "${config.home.homeDirectory}/.vibe/hooks.toml" toml toml \
          '.hooks = (((.hooks // []) | map(select(.name != "lean-ctx-redirect"))) + [{"name": "lean-ctx-redirect", "type": "pre_tool", "match": "re:(bash|read_file|grep)", "command": "${agentExecutables.leanCtx} hook vibe-pre-tool", "timeout": 60.0, "description": "Route native bash through lean-ctx; steer read_file/grep to ctx_* tools"}])'
        update_structured_config \
          "${config.home.homeDirectory}/.config/opencode/opencode.json" json json \
          '.mcp = ((.mcp // {}) + {"engram": {"command": ["${agentExecutables.engram}", "mcp"], "enabled": true, "type": "local"}, "lean-ctx": {"command": ["${agentExecutables.leanCtx}"], "enabled": true, "type": "local"}, "qartez": {"command": ["${agentExecutables.qartez}"], "enabled": true, "type": "local"}})'

        codex_executable=${lib.getExe local.codex}
        $DRY_RUN_CMD "$codex_executable" mcp remove lean-ctx >/dev/null 2>&1 || true

        $DRY_RUN_CMD "$codex_executable" mcp remove headroom >/dev/null 2>&1 || true
        $DRY_RUN_CMD "$codex_executable" mcp remove serena >/dev/null 2>&1 || true

        $DRY_RUN_CMD "$codex_executable" mcp remove qartez >/dev/null 2>&1 || true
        $DRY_RUN_CMD "$codex_executable" mcp add qartez -- \
          ${agentExecutables.qartez}

        $DRY_RUN_CMD "$codex_executable" mcp remove engram >/dev/null 2>&1 || true
        $DRY_RUN_CMD "$codex_executable" mcp add engram -- \
          ${agentExecutables.engram} mcp

        $DRY_RUN_CMD "$codex_executable" mcp remove lean-ctx >/dev/null 2>&1 || true
        $DRY_RUN_CMD "$codex_executable" mcp add lean-ctx -- \
          ${agentExecutables.leanCtx}
      '';

      headroomLeanCtxAddon = lib.hm.dag.entryAfter ["agentMcpServers"] ''
        if ! $DRY_RUN_CMD ${lib.getExe local.lean-ctx} addon add \
          ${headroomLeanCtxAddonManifest} --yes; then
          echo "warning: failed to register Headroom with the LeanCTX gateway" >&2
        fi
      '';
    };
  };
}
