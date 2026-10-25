{den, ...}: {
  den.aspects = {
    development-core = {
      includes = with den.aspects; [
        code-navigation
        pi
      ];
      homeManager = {
        imports = [
          ./_core.nix
        ];
      };
    };
    development-mantle = {
      includes = with den.aspects; [
        agent-memory
      ];
      homeManager = {
        imports = [
          ./_mantle.nix
        ];
      };
    };
    development = {
      includes = with den.aspects; [
        development-core
        development-mantle
      ];
      homeManager = {
        imports = [
          ./_security.nix
          ./_tooling.nix
        ];
      };
    };
    development-lab = {
      homeManager = {
        imports = [
          ./_lab.nix
        ];
      };
    };
    gamedev-forge = {
      homeManager = {
        imports = [
          ./_gamedev-forge.nix
        ];
      };
    };
    cloud = {
      homeManager = {
        imports = [
          ./_cloud.nix
        ];
      };
    };
  };
}
