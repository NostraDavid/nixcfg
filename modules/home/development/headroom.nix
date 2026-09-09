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

  # Run after other client configuration writers and Home Manager symlinks.
  home.activation.headroomClients = lib.hm.dag.entryAfter ["agentMemoryClients" "linkGeneration"] ''
    $DRY_RUN_CMD ${python}/bin/python ${./headroom-clients.py} \
      ${lib.escapeShellArg config.home.homeDirectory} ${local.headroom}/bin/headroom
  '';
}
