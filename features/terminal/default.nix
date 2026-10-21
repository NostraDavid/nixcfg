{den, ...}: {
  den.aspects = {
    locate.homeManager.imports = [./_locate.nix];
    terminal-core = {
      includes = [den.aspects.locate];
      homeManager = {
        imports = [
          ./_config.nix
        ];
      };
    };
    terminal = {
      includes = with den.aspects; [
        terminal-core
      ];
      homeManager = {
        imports = [
          ./_packages.nix
        ];
      };
    };
  };
}
