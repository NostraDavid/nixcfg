{den, ...}: {
  den.aspects.interactive = {
    includes = with den.aspects; [
      annotation
      common-tooling
      mcp
      nix-index
      worktrunk
    ];
  };
}
