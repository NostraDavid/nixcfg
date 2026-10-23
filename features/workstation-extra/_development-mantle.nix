{
  lib,
  stable,
  unstable,
  ...
}: let
  isX86Linux = stable.stdenv.hostPlatform.system == "x86_64-linux";
in
  {
    home.packages = [
      unstable.rtk
      unstable.snip
    ];
  }
  // lib.optionalAttrs isX86Linux {
    nixcfg.agentMemory.provider = "engrim";
  }
