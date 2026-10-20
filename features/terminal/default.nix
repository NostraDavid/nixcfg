{den, ...}: {
  den.aspects = {
    terminal-core = {
      homeManager = {imports = [./_config.nix];};
    };
    terminal = {
      includes = with den.aspects; [terminal-core];
      homeManager = {imports = [./_packages.nix];};
    };
  };
}
