{den, ...}: {
  den.aspects.interactive = {
    includes = with den.aspects; [mcp nix-index worktrunk annotation common-tooling];
  };
}
