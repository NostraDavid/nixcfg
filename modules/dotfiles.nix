# home/common.nix
# Shared home-manager configuration for all hosts.
{config, ...}: {
  # This list may look a little weird, but that's because the original dotfiles
  # were managed by `stow`, which needs this folder structure to work correctly.
  # I decided to keep it that way, so I could return to stow in the future.
  home.file = let
    dot = "${config.home.homeDirectory}/dev/NostraDavid/nixcfg/trunk/dotfiles";
    mk = path: config.lib.file.mkOutOfStoreSymlink path;
    forceAll = builtins.mapAttrs (_: file: file // {force = true;});
  in
    forceAll {
      # cli-proxies

      ## Generic
      "AGENTS.md" = {source = mk "${dot}/codex-0.140.0/.codex/AGENTS.md";};
      "agent-rules" = {source = mk "${dot}/agent-rules";};

      ## Codex
      ".codex/config.toml" = {source = mk "${dot}/codex-0.140.0/.codex/config.toml";};
      ".codex/AGENTS.md" = {source = mk "${dot}/codex-0.140.0/.codex/AGENTS.md";};
      ".codex/rules/default.rules" = {source = mk "${dot}/codex-0.140.0/.codex/rules/default.rules";};
      ".codex/skills/database-design" = {source = mk "${dot}/codex-0.140.0/.codex/skills/database-design";};
      ".codex/skills/manage-adrs" = {source = mk "${dot}/codex-0.140.0/.codex/skills/manage-adrs";};

      ## pi
      ".pi/agent/settings.json" = {source = mk "${dot}/pi/.pi/agent/settings.json";};
      ".pi/agent/AGENTS.md" = {source = mk "${dot}/pi/.pi/agent/AGENTS.md";};

      ## Claude
      ".claude/settings.json" = {source = mk "${dot}/claude-1.0/.claude/settings.json";};
      ".claude/CLAUDE.md" = {source = mk "${dot}/claude-1.0/.claude/CLAUDE.md";};

      ## Copilot
      ".copilot/hooks/cli-proxy.json" = {source = mk "${dot}/copilot-1.0/.copilot/hooks/cli-proxy.json";};
      ".copilot/copilot-instructions.md" = {source = mk "${dot}/copilot-1.0/.copilot/copilot-instructions.md";};

      ## RTK
      ".config/rtk/config.toml" = {source = mk "${dot}/rtk-0.41.0/.config/rtk/config.toml";};

      ## snip
      ".config/snip/config.toml" = {source = mk "${dot}/snip-0.18.0/.config/snip/config.toml";};
      ".config/snip/filters" = {source = mk "${dot}/snip-0.18.0/.config/snip/filters";};

      # The rest
      ".bash_aliases" = {source = mk "${dot}/bash-5.2.37/.bash_aliases";};
      ".bash_profile" = {source = mk "${dot}/bash-5.2.37/.bash_profile";};
      ".bashrc" = {source = mk "${dot}/bash-5.2.37/.bashrc";};
      ".config/bat/config" = {source = mk "${dot}/bat-0.25.0/.config/bat/config";};
      ".config/btop/btop.conf" = {source = mk "${dot}/btop/btop.conf";};
      ".config/Code/User/keybindings.json" = {source = mk "${dot}/vscode/.config/Code/User/keybindings.json";};
      ".config/Code/User/settings.json" = {source = mk "${dot}/vscode/.config/Code/User/settings.json";};
      ".config/fastfetch/" = {source = mk "${dot}/fastfetch-2.58.0/.config/fastfetch";};
      ".config/git/attributes" = {source = mk "${dot}/git/.config/git/attributes";};
      ".config/git/commit-template" = {source = mk "${dot}/git/.config/git/commit-template";};
      ".config/git/hooks" = {source = mk "${dot}/git/.config/git/hooks";};
      ".config/ghostty/config.ghostty" = {source = mk "${dot}/ghostty-1.3.1/.config/ghostty/config.ghostty";};
      ".config/markdownlint/config.yaml" = {source = mk "${dot}/markdownlint-cli-0.46.0/.config/markdownlint/config.yaml";};
      ".config/mpv/mpv.conf" = {source = mk "${dot}/mpv/.config/mpv/mpv.conf";};
      ".config/nvim/" = {source = mk "${dot}/neovim-0.11/.config/nvim";};
      ".config/pip/pip.conf" = {source = mk "${dot}/pip-22+/.config/pip/pip.conf";};
      ".config/powerline" = {source = mk "${dot}/powerline-bash/.config/powerline";};
      ".config/pypoetry/" = {source = mk "${dot}/pypoetry-2.1/.config/pypoetry";};
      ".config/RSS Guard 4/config/config.ini" = {source = mk "${dot}/rssguard-4/.config/RSS Guard 4/config/config.ini";};
      ".config/starship.toml" = {source = mk "${dot}/starship-1.23.0/.config/starship.toml";};
      ".config/uv/uv.toml" = {source = mk "${dot}/uv-0.9.0/.config/uv/uv.toml";};
      ".config/wezterm/wezterm.lua" = {source = mk "${dot}/wezterm-0-unstable-2025-05-18/.config/wezterm/wezterm.lua";};
      ".config/zigfetch/" = {source = mk "${dot}/zigfetch-0.25.0/.config/zigfetch";};
      ".git-templates" = {source = mk "${dot}/git-templates/.git-templates";};
      ".gitconfig" = {source = mk "${dot}/git/.gitconfig";};
      ".groovylintrc.json" = {source = mk "${dot}/groovy-lint/.groovylintrc.json";};
      ".inputrc" = {source = mk "${dot}/readline/.inputrc";};
      ".local/bin/code" = {source = mk "${dot}/scripts/code";};
      ".local/bin/folder_stats" = {source = mk "${dot}/scripts/folder_stats";};
      ".local/bin/project_color" = {source = mk "${dot}/scripts/project_color";};
      ".local/bin/project_picker" = {source = mk "${dot}/scripts/project_picker";};
      ".local/bin/venv" = {source = mk "${dot}/scripts/venv";};
      ".tmux.conf" = {source = mk "${dot}/tmux-3.5a/.tmux.conf";};
      ".vim" = {source = mk "${dot}/vim-9.0/.vim";};
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
