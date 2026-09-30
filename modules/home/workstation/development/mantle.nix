{
  lib,
  local,
  stable,
  unstable,
  ...
}: let
  isX86Linux = stable.stdenv.hostPlatform.system == "x86_64-linux";
in
  {
    imports = lib.optionals isX86Linux [
      ../../development/agent-memory.nix
      ../../development/headroom.nix
    ];

    home.packages =
      [unstable.rtk unstable.snip]
      ++ lib.optionals isX86Linux [
        local.pi-coding-agent
        local.qartez
      ];
  }
  // lib.optionalAttrs isX86Linux {
    nixcfg.agentMemory.provider = "engrim";
  }
