{den, ...}: {
  den.aspects.interactive = {
    includes = with den.aspects; [
      annotation
      common-tooling
      locate
      mcp
      nix-index
      worktrunk
    ];
  };
}
