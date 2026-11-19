{den, ...}: {
  den.aspects = {
    agent-memory = {
      homeManager = {
        imports = [
          ./_agent-memory.nix
        ];
      };
    };
    mcp = {
      includes = with den.aspects; [
        agent-memory
      ];
      homeManager = {
        imports = [
          ./_home.nix
        ];
      };
    };
  };
}
