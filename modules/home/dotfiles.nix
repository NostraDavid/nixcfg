# Shared home-manager configuration for all hosts.
{
  config,
  local,
  lib,
  repoRoot,
  stable,
  unstable,
  ...
}: let
  ponytailMarketplace = stable.writeText "configure-codex-ponytail.py" ''
    import json
    import os
    import shutil
    import sys
    import tempfile
    from pathlib import Path

    home = Path(sys.argv[1])
    path = home / ".agents/plugins/marketplace.json"
    original = ""
    entry = {
        "name": "ponytail",
        "source": {"source": "local", "path": "./plugins/ponytail"},
        "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
        "category": "Productivity",
    }

    if path.exists():
        try:
            original = path.read_text()
            document = json.loads(original)
        except (OSError, json.JSONDecodeError) as error:
            print(f"warning: cannot read {path}: {error}", file=sys.stderr)
            raise SystemExit(0)
        if not isinstance(document, dict):
            print(f"warning: ignoring non-object Codex marketplace {path}", file=sys.stderr)
            raise SystemExit(0)
    else:
        document = {"name": "personal", "interface": {"displayName": "Personal"}, "plugins": []}

    marketplace_name = document.get("name", "personal")
    if marketplace_name != "personal":
        print(
            f"warning: leaving non-personal Codex marketplace {path} ({marketplace_name!r}) unchanged",
            file=sys.stderr,
        )
        raise SystemExit(0)

    plugins = document.get("plugins", [])
    if not isinstance(plugins, list):
        print(f"warning: ignoring malformed plugin list in {path}", file=sys.stderr)
        raise SystemExit(0)
    interface = document.get("interface", {})
    if not isinstance(interface, dict):
        print(f"warning: ignoring malformed marketplace interface in {path}", file=sys.stderr)
        raise SystemExit(0)
    document["name"] = "personal"
    interface.setdefault("displayName", "Personal")
    document["interface"] = interface
    document["plugins"] = [plugin for plugin in plugins if not (isinstance(plugin, dict) and plugin.get("name") == "ponytail")]
    document["plugins"].append(entry)
    updated = json.dumps(document, indent=2, ensure_ascii=False) + "\n"
    if updated == original:
        raise SystemExit(0)

    path.parent.mkdir(parents=True, exist_ok=True)
    backup = path.with_name(path.name + ".before-ponytail")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(updated)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
  '';
in {
  imports = [./portable-dotfiles.nix];

  # This list may look a little weird, but that's because the original dotfiles
  # were managed by `stow`, which needs this folder structure to work correctly.
  # I decided to keep it that way, so I could return to stow in the future.
  home = {
    file = let
      dot = "${repoRoot}/dotfiles";
      mk = path: config.lib.file.mkOutOfStoreSymlink path;
      forceAll = builtins.mapAttrs (_: file: file // {force = true;});
      skillCatalog = builtins.fromJSON (builtins.readFile ../../dotfiles/agents/skills.json);
      skillAlias = name: skillCatalog.aliases.${name} or name;
      workflowSkills = skillCatalog.workflow;
      mbrolaNl2 = stable.mbrola-voices.override {languages = ["nl2"];};
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
          "plugins/ponytail" = {source = local.ponytail-codex;};
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
          ".config/Code/User/keybindings.json" = {source = mk "${dot}/vscode/.config/Code/User/keybindings.json";};
          ".config/Code/User/mcp.json" = {source = mk "${dot}/vscode/.config/Code/User/mcp.json";};
          ".config/Code/User/settings.json" = {source = mk "${dot}/vscode/.config/Code/User/settings.json";};
          ".config/git/identity.conf" = {source = mk "${dot}/git/.config/git/identity.conf";};
          ".config/i3/config" = {source = mk "${dot}/i3/.config/i3/config";};
          ".config/mpv/mpv.conf" = {source = mk "${dot}/mpv/.config/mpv/mpv.conf";};
          ".config/niri/config.kdl" = {source = mk "${dot}/niri/.config/niri/config.kdl";};
          ".groovylintrc.json" = {source = mk "${dot}/groovy-lint/.groovylintrc.json";};
          ".local/bin/code" = {source = mk "${dot}/scripts/code.sh";};
          ".local/bin/generate_gitignore" = {source = mk "${dot}/scripts/generate_gitignore.py";};
          ".local/bin/ide" = {source = mk "${dot}/scripts/ide.py";};
          ".local/bin/pde" = {source = mk "${dot}/scripts/pde.py";};
          ".local/bin/folder_stats" = {source = mk "${dot}/scripts/folder_stats.py";};
          ".local/bin/project_color" = {source = mk "${dot}/scripts/project_color.py";};
          ".local/bin/project_picker" = {source = mk "${dot}/scripts/project_picker.py";};
          ".local/bin/say" = {source = mk "${dot}/scripts/say.sh";};
          ".local/bin/say-espeak-ng" = {source = mk "${dot}/scripts/say-espeak-ng.sh";};
          ".local/bin/say-espeak-ng-mbrola" = {source = mk "${dot}/scripts/say-espeak-ng-mbrola.sh";};
          ".local/bin/say-piper-tts" = {source = mk "${dot}/scripts/say-piper-tts.sh";};
          ".config/say/espeak-ng-data" = {source = "${local.say-dictionary}/share/espeak-ng-data";};
          ".local/share/mbrola/nl2" = {source = "${mbrolaNl2}/data/nl2";};
          ".local/share/piper-voices/en_US-amy-medium.onnx" = {source = mk "${dot}/piper-voices/en_US-amy-medium.onnx";};
          ".local/share/piper-voices/en_US-amy-medium.onnx.json" = {source = mk "${dot}/piper-voices/en_US-amy-medium.onnx.json";};
          ".local/share/piper-voices/nl_NL-mls-medium.onnx" = {source = mk "${dot}/piper-voices/nl_NL-mls-medium.onnx";};
          ".local/share/piper-voices/nl_NL-mls-medium.onnx.json" = {source = mk "${dot}/piper-voices/nl_NL-mls-medium.onnx.json";};
          ".local/share/piper-voices/nl_NL-pim-medium.onnx" = {source = mk "${dot}/piper-voices/nl_NL-pim-medium.onnx";};
          ".local/share/piper-voices/nl_NL-pim-medium.onnx.json" = {source = mk "${dot}/piper-voices/nl_NL-pim-medium.onnx.json";};
          ".local/bin/tmux-login-session" = {source = mk "${dot}/scripts/tmux-login-session";};
          ".local/bin/venv" = {source = mk "${dot}/scripts/venv.py";};
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

    activation.codexPonytail = lib.hm.dag.entryAfter ["linkGeneration"] ''
      $DRY_RUN_CMD ${stable.python3}/bin/python ${ponytailMarketplace} ${lib.escapeShellArg config.home.homeDirectory}
      if ! $DRY_RUN_CMD ${unstable.codex}/bin/codex plugin add ponytail@personal --json >/dev/null 2>&1; then
        echo "warning: failed to install Codex plugin ponytail" >&2
      fi
    '';

    activation.skillDescriptions = lib.hm.dag.entryAfter ["codexPonytail"] ''
      $DRY_RUN_CMD ${stable.python3.withPackages (ps: [ps.pyyaml])}/bin/python \
        ${./skill-descriptions.py} ${../../dotfiles/agents/descriptions.json} \
        "${config.home.homeDirectory}/.codex/skills/.system" \
        "${config.home.homeDirectory}/.codex/plugins/cache"
    '';
  };
}
