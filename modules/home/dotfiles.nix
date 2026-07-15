# Shared home-manager configuration for all hosts.
{
  config,
  repoRoot,
  ...
}: {
  # This list may look a little weird, but that's because the original dotfiles
  # were managed by `stow`, which needs this folder structure to work correctly.
  # I decided to keep it that way, so I could return to stow in the future.
  home.file = let
    dot = "${repoRoot}/dotfiles";
    mk = path: config.lib.file.mkOutOfStoreSymlink path;
    forceAll = builtins.mapAttrs (_: file: file // {force = true;});
  in
    forceAll {
      # cli-proxies

      ## Generic
      "AGENTS.md" = {source = mk "${dot}/agent-rules/AGENTS.md";};
      "agent-rules" = {source = mk "${dot}/agent-rules";};

      ## Codex
      ".codex/AGENTS.md" = {source = mk "${dot}/agent-rules/AGENTS.md";};
      ".codex/skills/database-design" = {source = mk "${dot}/codex-0.140.0/.codex/skills/database-design";};
      ".codex/skills/manage-adrs" = {source = mk "${dot}/codex-0.140.0/.codex/skills/manage-adrs";};

      ## pi
      ".pi/agent/settings.json" = {source = mk "${dot}/pi/.pi/agent/settings.json";};
      ".pi/agent/AGENTS.md" = {source = mk "${dot}/agent-rules/AGENTS.md";};

      ## Gemini
      ".gemini/GEMINI.md" = {source = mk "${dot}/agent-rules/AGENTS.md";};

      ## Claude
      ".claude/settings.json" = {source = mk "${dot}/claude-1.0/.claude/settings.json";};
      ".claude/CLAUDE.md" = {source = mk "${dot}/agent-rules/AGENTS.md";};

      ## Copilot
      ".copilot/hooks/cli-proxy.json" = {source = mk "${dot}/copilot-1.0/.copilot/hooks/cli-proxy.json";};
      ".copilot/copilot-instructions.md" = {source = mk "${dot}/copilot-1.0/.copilot/copilot-instructions.md";};
      ".copilot/instructions/eu-ai-act.instructions.md" = {source = mk "${dot}/agent-rules/eu-ai-act.md";};
      ".copilot/prompts" = {source = mk "${dot}/copilot-1.0/.copilot/prompts";};
      ".copilot/settings.json" = {source = mk "${dot}/copilot-1.0/.copilot/settings.json";};

      ## OpenCode
      ".config/opencode/opencode.json".text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        instructions = ["${config.home.homeDirectory}/agent-rules/eu-ai-act.md"];
      };

      ## Hermes
      ".hermes/SOUL.md".text = ''
        You are Hermes Agent, an intelligent AI assistant created by Nous Research. You are helpful, knowledgeable, and direct. You assist users with a wide range of tasks including answering questions, writing and editing code, analyzing information, creative work, and executing actions via your tools. You communicate clearly, admit uncertainty when appropriate, and prioritize being genuinely useful over being verbose unless otherwise directed below. Be targeted and efficient in your exploration and investigations.

        ${builtins.readFile ../../dotfiles/agent-rules/eu-ai-act.md}
      '';

      ## RTK
      ".config/rtk/config.toml" = {source = mk "${dot}/rtk-0.41.0/.config/rtk/config.toml";};

      ## snip
      ".config/snip/config.toml" = {source = mk "${dot}/snip-0.18.0/.config/snip/config.toml";};
      ".config/snip/filters" = {source = mk "${dot}/snip-0.18.0/.config/snip/filters";};

      # The rest
      ".config/Code/User/keybindings.json" = {source = mk "${dot}/vscode/.config/Code/User/keybindings.json";};
      ".config/Code/User/settings.json" = {source = mk "${dot}/vscode/.config/Code/User/settings.json";};
      ".config/git/attributes" = {source = mk "${dot}/git/.config/git/attributes";};
      ".config/git/commit-template" = {source = mk "${dot}/git/.config/git/commit-template";};
      ".config/git/hooks" = {source = mk "${dot}/git/.config/git/hooks";};
      ".config/git/ignore" = {source = mk "${dot}/git/.config/git/ignore";};
      ".config/markdownlint/config.yaml" = {source = mk "${dot}/markdownlint-cli-0.46.0/.config/markdownlint/config.yaml";};
      ".config/mpv/mpv.conf" = {source = mk "${dot}/mpv/.config/mpv/mpv.conf";};
      ".config/nvim/" = {source = mk "${dot}/neovim-0.11/.config/nvim";};
      ".config/pip/pip.conf" = {source = mk "${dot}/pip-22+/.config/pip/pip.conf";};
      ".config/pypoetry/" = {source = mk "${dot}/pypoetry-2.1/.config/pypoetry";};
      ".config/RSS Guard 4/config/config.ini" = {source = mk "${dot}/rssguard-4/.config/RSS Guard 4/config/config.ini";};
      ".config/uv/uv.toml" = {source = mk "${dot}/uv-0.9.0/.config/uv/uv.toml";};
      ".git-templates" = {source = mk "${dot}/git-templates/.git-templates";};
      ".gitconfig" = {source = mk "${dot}/git/.gitconfig";};
      ".groovylintrc.json" = {source = mk "${dot}/groovy-lint/.groovylintrc.json";};
      ".local/bin/code" = {source = mk "${dot}/scripts/code";};
      ".local/bin/folder_stats" = {source = mk "${dot}/scripts/folder_stats";};
      ".local/bin/project_color" = {source = mk "${dot}/scripts/project_color";};
      ".local/bin/project_picker" = {source = mk "${dot}/scripts/project_picker";};
      ".local/bin/tmux-login-session" = {source = mk "${dot}/scripts/tmux-login-session";};
      ".local/bin/venv" = {source = mk "${dot}/scripts/venv";};
      ".vimrc" = {source = mk "${dot}/vim-9.0/.vimrc";};
      "dev/.env.example" = {source = mk "${dot}/dev/.env.example";};
      "dev/find-uncommitted.py" = {source = mk "${dot}/dev/find-uncommitted.py";};
      "dev/get_azure_repos.py" = {source = mk "${dot}/dev/get_azure_repos.py";};
      "dev/grab.py" = {source = mk "${dot}/dev/grab.py";};
      "dev/repos.dat" = {source = mk "${dot}/dev/repos.dat";};
      "dev/restore_repos.py" = {source = mk "${dot}/dev/restore_repos.py";};
      "dev/save_cloned_repos.py" = {source = mk "${dot}/dev/save_cloned_repos.py";};
      "dev/update_all_local_repos.py" = {source = mk "${dot}/dev/update_all_local_repos.py";};
      "rsync-bitvavo" = {source = mk "${dot}/scripts/rsync-bitvavo";};
      # ".config/voxtype/config.toml" = {source = mk "${dot}/voxtype/.config/voxtype/config.toml";};
    };

  home.sessionVariables = {};
}
