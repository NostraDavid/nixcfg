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
    # Retire legacy resources after Home Manager creates its symlinks.
    activation.headroomClients =
      lib.hm.dag.entryAfter [
        "linkGeneration"
      ] ''
        $DRY_RUN_CMD ${python}/bin/python ${./headroom-clients.py} \
          ${lib.escapeShellArg config.home.homeDirectory}
      '';
  };

  nixcfg.mcp.servers.headroom = {
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
