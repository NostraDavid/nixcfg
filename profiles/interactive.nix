{den, ...}: {
  den.aspects.interactive = {
    includes = with den.aspects; [
      annotation
      code-navigation
      common-tooling
      locate
      mcp
      nix-index
      worktrunk
    ];
  };
}
