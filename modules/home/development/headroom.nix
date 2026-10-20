{
  config,
  lib,
  local,
  stable,
  ...
}: let
  python = stable.python3.withPackages (p: [p.tomlkit]);
in {
  home.packages = [local.headroom];

  programs.pi.coding-agent.mcp.mcpServers.headroom = {
    command = "${local.headroom}/bin/headroom";
    args = ["mcp" "serve" "--transport" "stdio"];
    description = "Compress large tool outputs and retrieve original evidence";
  };

  # Run after other client configuration writers and Home Manager symlinks.
  home.activation.headroomClients = lib.hm.dag.entryAfter ["agentMemoryClients" "linkGeneration"] ''
    $DRY_RUN_CMD ${python}/bin/python ${./headroom-clients.py} \
      ${lib.escapeShellArg config.home.homeDirectory} ${local.headroom}/bin/headroom
  '';
}
