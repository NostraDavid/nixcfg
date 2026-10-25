{den, ...}: {
  den.aspects = {
    agent-memory = {
      homeManager = {
        imports = [
          ./_agent-memory.nix
        ];
      };
    };
    pi = {
      homeManager = {
        imports = [
          ./_pi.nix
        ];
      };
    };
    mcp = {
      includes = with den.aspects; [
        agent-memory
        pi
      ];
      homeManager = {
        imports = [
          ./_home.nix
        ];
      };
    };
  };
}
