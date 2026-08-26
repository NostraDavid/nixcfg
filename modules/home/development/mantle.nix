{
  config,
  lib,
  local,
  stable,
  unstable,
  ...
}: {
  programs.pi.coding-agent = {
    enable = true;
    settings = builtins.fromJSON (
      builtins.readFile ../../../dotfiles/pi/.pi/agent/settings.json
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
      unstable.codex # llm agent
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
    };
  };
}
