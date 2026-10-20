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
    home.packages =
      [
        unstable.rtk
        unstable.snip
      ]
      ++ lib.optionals isX86Linux [
        local.pi-coding-agent
      ];
  }
  // lib.optionalAttrs isX86Linux {
    nixcfg.agentMemory.provider = "engrim";
  }
