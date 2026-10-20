{
  config,
  lib,
  local,
  stable,
  ...
}: let
  python = stable.python3;
in {
  home = {
    packages = [
      local.headroom
    ];
    file.".local/bin/headroom".source = "${local.headroom}/bin/headroom";
    # Run after other client configuration writers and Home Manager symlinks.
    activation.headroomClients =
      lib.hm.dag.entryAfter [
        "linkGeneration"
      ] ''
        $DRY_RUN_CMD ${python}/bin/python ${./headroom-clients.py} \
          ${lib.escapeShellArg config.home.homeDirectory}
      '';
  };

  programs.pi.coding-agent.mcp.mcpServers.headroom = {
    command = "${config.home.homeDirectory}/.local/bin/headroom";
    args = [
      "mcp"
      "serve"
      "--transport"
      "stdio"
    ];
    description = "Compress large tool outputs and retrieve original evidence";
  };
}
