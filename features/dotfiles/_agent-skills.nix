{
  config,
  local,
  repoRoot,
  stable,
  ...
}: let
  dot = "${repoRoot}/dotfiles";
  mk = path: config.lib.file.mkOutOfStoreSymlink path;
  forceAll = builtins.mapAttrs (_: file: file // {force = true;});
  skillCatalog = builtins.fromJSON (builtins.readFile ../../dotfiles/agents/skills.json);
  skillAlias = name: skillCatalog.aliases.${name} or name;
  workflowSkills = skillCatalog.workflow;
  localSkills = skillCatalog.local ++ workflowSkills;
  importedSkills = [
    local.awesome-copilot-skills
    local.matt-pocock-skills
    local.polars-skills
    local.ponytail-skills
    local.pstack-skills
  ];
  namedSkills =
    stable.runCommand "short-skill-names" {
      nativeBuildInputs = [
        (stable.python3.withPackages (ps: [
          ps.pyyaml
        ]))
      ];
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
  sharedAgentSkills = mkSkillLinks "agents" skillEntries;
  copilotSkills = mkSkillLinks "copilot" skillEntries;
  opencodeSkills = mkSkillLinks "config/opencode" skillEntries;
in {
  home.file = forceAll (
    sharedCodexSkills
    // sharedAgentSkills
    // copilotSkills
    // opencodeSkills
    // {
      ".local/bin/generate_gitignore".source = mk "${dot}/agents/.agents/gitignore/scripts/generate_gitignore.py";
      ".pi/agent/skills/ctx".source = "${namedSkills}/ctx";
    }
  );
}
