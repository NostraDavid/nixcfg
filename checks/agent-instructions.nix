{
  pkgs,
  homeFiles,
}: let
  catalog = builtins.fromJSON (builtins.readFile ../dotfiles/agents/skills.json);
  names = catalog.local ++ catalog.workflow;
  wanted =
    builtins.concatMap
    (client: map (name: ".${client}/skills/${name}") names)
    ["codex" "copilot" "config/opencode"]
    ++ map (name: ".agents/skills/${name}") catalog.workflow;
  links = builtins.listToAttrs (map (name: {
      inherit name;
      value = toString homeFiles.${name}.source;
    })
    wanted);
in
  pkgs.runCommand "agent-instructions-check" {
    nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.pyyaml]))];
    AGENT_SOURCE = ../dotfiles/agents;
    AGENT_LINKS = pkgs.writeText "agent-skill-links.json" (builtins.toJSON links);
  } ''
    python ${./test_agent_instructions.py}
    touch "$out"
  ''
