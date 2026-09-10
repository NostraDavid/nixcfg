{
  pkgs,
  homeFiles,
}: let
  catalog = builtins.fromJSON (builtins.readFile ../dotfiles/agents/skills.json);
  alias = name: catalog.aliases.${name} or name;
  encodingUrl = "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken";
  encodingData = pkgs.fetchurl {
    url = encodingUrl;
    sha256 = "446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d";
  };
  wanted =
    builtins.concatMap
    (client: map (name: ".${client}/skills/${alias name}") (builtins.attrNames catalog.aliases))
    ["codex" "copilot" "config/opencode"]
    ++ map (name: ".agents/skills/${alias name}") catalog.workflow;
  links = builtins.listToAttrs (map (name: {
      inherit name;
      value = toString homeFiles.${name}.source;
    })
    wanted);
in
  pkgs.runCommand "agent-instructions-check" {
    nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.pyyaml ps.tiktoken]))];
    AGENT_SOURCE = ../dotfiles/agents;
    DESCRIPTION_REWRITER = ../modules/home/skill-descriptions.py;
    TRIGGER_CASES = ./skill-trigger-cases.json;
    AGENT_LINKS = pkgs.writeText "agent-skill-links.json" (builtins.toJSON links);
  } ''
    export TIKTOKEN_CACHE_DIR="$TMPDIR/tiktoken"
    mkdir -p "$TIKTOKEN_CACHE_DIR"
    cp ${encodingData} "$TIKTOKEN_CACHE_DIR/${builtins.hashString "sha1" encodingUrl}"
    python ${./test_agent_instructions.py}
    touch "$out"
  ''
