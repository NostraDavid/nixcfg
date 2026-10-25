{den, ...}: {
  den.aspects = {
    agent-memory = {
      homeManager = {
        imports = [
          ./_agent-memory.nix
        ];
      };
    };
    headroom = {
      homeManager = {
        imports = [
          ./_headroom.nix
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
        headroom
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
