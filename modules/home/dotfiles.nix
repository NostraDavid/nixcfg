# Shared home-manager configuration for all hosts.
{
  config,
  local,
  lib,
  repoRoot,
  stable,
  ...
}: {
  # This list may look a little weird, but that's because the original dotfiles
  # were managed by `stow`, which needs this folder structure to work correctly.
  # I decided to keep it that way, so I could return to stow in the future.
  home.file = let
    dot = "${repoRoot}/dotfiles";
    mk = path: config.lib.file.mkOutOfStoreSymlink path;
    forceAll = builtins.mapAttrs (_: file: file // {force = true;});
    skillCatalog = builtins.fromJSON (builtins.readFile ../../dotfiles/agents/skills.json);
    skillAlias = name: skillCatalog.aliases.${name} or name;
    workflowSkills = skillCatalog.workflow;
    localSkills = skillCatalog.local ++ workflowSkills;
    importedSkills = [local.awesome-copilot-skills local.blender-mcp-skills local.blender-reference-skills local.cc-blender-skills local.matt-pocock-skills local.polars-skills local.ponytail-skills local.pstack-skills];
    namedSkills =
      stable.runCommand "short-skill-names" {
        nativeBuildInputs = [(stable.python3.withPackages (ps: [ps.pyyaml]))];
      } ''
        mkdir -p "$out"
        ${builtins.concatStringsSep "\n" (map (package:
          builtins.concatStringsSep "\n" (map (name: ''
              cp -RL ${package}/${name} "$out/${name}"
            '')
            package.skillNames))
        importedSkills)}
        cp -RL ${local.ctx}/share/skills/ctx "$out/ctx"
        chmod -R u+w "$out"
        python - "$out" ${../../dotfiles/agents/skills.json} <<'PY'
        import json
        import re
        import sys
        from pathlib import Path

        root = Path(sys.argv[1])
        aliases = json.loads(Path(sys.argv[2]).read_text())["aliases"]
        # Rewrite skill references, keeping source paths and ordinary words intact.
        references = re.compile(
            r"(?<![\w./-])(?:" + "|".join(re.escape(n) for n in aliases if "-" in n) + r")(?![\w./-])"
        )
        invocations = re.compile(
            r"(?<![\w./:])([$/])(" + "|".join(re.escape(n) for n in aliases) + r")(?![\w./-])"
        )
        for path in root.rglob("*.md"):
            text = path.read_text()
            if path.name == "SKILL.md" and path.parent.name in aliases:
                front, body = text.removeprefix("---\n").split("\n---", 1)
                front, count = re.subn(r"^name:.*$", "name: " + aliases[path.parent.name], front, count=1, flags=re.M)
                assert count == 1, path
                text = "---\n" + front + "\n---" + body
            text = references.sub(lambda match: aliases[match[0]], text)
            text = invocations.sub(lambda match: match[1] + aliases[match[2]], text)
            path.write_text(text)
        PY
        python ${./skill-descriptions.py} ${../../dotfiles/agents/descriptions.json} "$out"
      '';
    importedEntries =
      builtins.concatMap
      (package:
        map (name: {
          inherit name;
          source = "${namedSkills}/${name}";
        })
        package.skillNames)
      importedSkills;
    skillEntries =
      importedEntries
      ++ [
        {
          name = "ctx";
          source = "${namedSkills}/ctx";
        }
      ]
      ++ map (name: {
        inherit name;
        source = mk "${dot}/agents/.agents/${name}";
      })
      localSkills;
    mkSkillLinks = client: skills: let
      links = builtins.listToAttrs (map (skill: {
          name = ".${client}/skills/${skillAlias skill.name}";
          value = {
            inherit (skill) source;
          };
        })
        skills);
    in
      if builtins.length (builtins.attrNames links) != builtins.length skills
      then throw "Duplicate skill names or aliases: each enabled skill needs a unique link name."
      else links;
    sharedCodexSkills = mkSkillLinks "codex" skillEntries;
    sharedWorkflowSkills = mkSkillLinks "agents" (builtins.filter
      (skill: builtins.elem skill.name workflowSkills)
      skillEntries);
    copilotSkills = mkSkillLinks "copilot" skillEntries;
    opencodeSkills = mkSkillLinks "config/opencode" skillEntries;
  in
    forceAll ({
        # cli-proxies

        ## Generic
        "AGENTS.md" = {source = mk "${dot}/agents/instructions/AGENTS.md";};
        ".agents/instructions" = {source = mk "${dot}/agents/instructions";};
        ".agents/audio-notify" = {source = mk "${dot}/agents/.agents/audio-notify";};

        ## Codex
        ".codex/AGENTS.md" = {source = mk "${dot}/agents/instructions/AGENTS.md";};
        ".codex/hooks.json" = {source = mk "${dot}/codex-0.140.0/.codex/hooks.json";};
        ## pi
        ".pi/agent/AGENTS.md" = {source = mk "${dot}/agents/instructions/AGENTS.md";};

        ## Claude
        ".claude/skills/ctx".source = "${namedSkills}/ctx";
        ".pi/agent/skills/ctx".source = "${namedSkills}/ctx";
        ".claude/settings.json" = {source = mk "${dot}/claude-1.0/.claude/settings.json";};
        ".claude/CLAUDE.md" = {source = mk "${dot}/agents/instructions/AGENTS.md";};

        ## Copilot
        ".copilot/hooks/cli-proxy.json" = {source = mk "${dot}/copilot-1.0/.copilot/hooks/cli-proxy.json";};
        ".copilot/copilot-instructions.md" = {source = mk "${dot}/agents/instructions/AGENTS.md";};
        ".copilot/instructions/eu-ai-act.instructions.md" = {source = mk "${dot}/agents/instructions/eu-ai-act.md";};
        ".copilot/mcp-config.json" = {source = mk "${dot}/copilot-1.0/.copilot/mcp-config.json";};
        ".copilot/prompts" = {source = mk "${dot}/copilot-1.0/.copilot/prompts";};
        ".copilot/settings.json" = {source = mk "${dot}/copilot-1.0/.copilot/settings.json";};

        ## OpenCode
        ".config/opencode/opencode.jsonc" = {source = mk "${dot}/opencode-1.18.4/.config/opencode/opencode.jsonc";};
        ".config/opencode/AGENTS.md" = {source = mk "${dot}/agents/instructions/AGENTS.md";};

        ## Shared MCP
        ".config/mcp/mcp.json" = {source = mk "${dot}/mcp/.config/mcp/mcp.json";};

        ## Hermes
        ".hermes/config.yaml" = {source = mk "${dot}/hermes-agent/.hermes/config.yaml";};

        ## Mistral Vibe
        ".vibe/config.toml" = {source = mk "${dot}/mistral-vibe/.vibe/config.toml";};
        ".vibe/hooks.toml" = {source = mk "${dot}/mistral-vibe/.vibe/hooks.toml";};

        ## Hermes
        ".hermes/SOUL.md".text = ''
          You are Hermes Agent, an intelligent AI assistant created by Nous Research. You are helpful, knowledgeable, and direct. You assist users with a wide range of tasks including answering questions, writing and editing code, analyzing information, creative work, and executing actions via your tools. You communicate clearly, admit uncertainty when appropriate, and prioritize being genuinely useful over being verbose unless otherwise directed below. Be targeted and efficient in your exploration and investigations.

          ${builtins.readFile ../../dotfiles/agents/instructions/eu-ai-act.md}
        '';

        # The rest
        ".config/cloc/options.txt" = {source = mk "${dot}/cloc-2.08/.config/cloc/options.txt";};
        ".config/Code/User/keybindings.json" = {source = mk "${dot}/vscode/.config/Code/User/keybindings.json";};
        ".config/Code/User/mcp.json" = {source = mk "${dot}/vscode/.config/Code/User/mcp.json";};
        ".config/Code/User/settings.json" = {source = mk "${dot}/vscode/.config/Code/User/settings.json";};
        ".config/dprint/dprint.jsonc" = {source = mk "${dot}/dprint-0.54.0/.config/dprint/dprint.jsonc";};
        ".config/git/attributes" = {source = mk "${dot}/git/.config/git/attributes";};
        ".config/git/commit-template" = {source = mk "${dot}/git/.config/git/commit-template";};
        ".config/git/hooks" = {source = mk "${dot}/git/.config/git/hooks";};
        ".config/git/ignore" = {source = mk "${dot}/git/.config/git/ignore";};
        ".config/i3/config" = {source = mk "${dot}/i3/.config/i3/config";};
        ".config/markdownlint/config.yaml" = {source = mk "${dot}/markdownlint-cli-0.46.0/.config/markdownlint/config.yaml";};
        ".config/mpv/mpv.conf" = {source = mk "${dot}/mpv/.config/mpv/mpv.conf";};
        ".config/niri/config.kdl" = {source = mk "${dot}/niri/.config/niri/config.kdl";};
        ".config/nvim/" = {source = mk "${dot}/neovim-0.11/.config/nvim";};
        ".config/pip/pip.conf" = {source = mk "${dot}/pip-22+/.config/pip/pip.conf";};
        ".config/pypoetry/" = {source = mk "${dot}/pypoetry-2.1/.config/pypoetry";};
        ".config/uv/uv.toml" = {source = mk "${dot}/uv-0.9.0/.config/uv/uv.toml";};
        ".git-templates" = {source = mk "${dot}/git-templates/.git-templates";};
        ".gitconfig" = {source = mk "${dot}/git/.gitconfig";};
        ".groovylintrc.json" = {source = mk "${dot}/groovy-lint/.groovylintrc.json";};
        ".local/bin/code" = {source = mk "${dot}/scripts/code.sh";};
        ".local/bin/generate_gitignore" = {source = mk "${dot}/scripts/generate_gitignore.py";};
        ".local/bin/ide" = {source = mk "${dot}/scripts/ide.py";};
        ".local/bin/pde" = {source = mk "${dot}/scripts/pde.py";};
        ".local/bin/folder_stats" = {source = mk "${dot}/scripts/folder_stats.py";};
        ".local/bin/project_color" = {source = mk "${dot}/scripts/project_color.py";};
        ".local/bin/project_picker" = {source = mk "${dot}/scripts/project_picker.py";};
        ".local/bin/say" = {source = mk "${dot}/scripts/say.sh";};
        ".config/say/espeak-ng-data" = {source = "${local.say-dictionary}/share/espeak-ng-data";};
        ".local/bin/tmux-login-session" = {source = mk "${dot}/scripts/tmux-login-session";};
        ".local/bin/venv" = {source = mk "${dot}/scripts/venv.py";};
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
      }
      // sharedCodexSkills
      // sharedWorkflowSkills
      // copilotSkills
      // opencodeSkills);

  home.activation.skillDescriptions = lib.hm.dag.entryAfter ["linkGeneration"] ''
    $DRY_RUN_CMD ${stable.python3.withPackages (ps: [ps.pyyaml])}/bin/python \
      ${./skill-descriptions.py} ${../../dotfiles/agents/descriptions.json} \
      "${config.home.homeDirectory}/.codex/skills/.system" \
      "${config.home.homeDirectory}/.codex/plugins/cache"
  '';
}
