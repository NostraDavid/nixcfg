{den, ...}: {
  den.aspects = {
    worktrunk = {
      homeManager = {
        imports = [
          ./_worktrunk.nix
        ];
      };
    };
    portable-dotfiles = {
      includes = with den.aspects; [
        worktrunk
      ];
      homeManager = {
        imports = [
          ./_portable-dotfiles.nix
        ];
      };
    };
    dotfiles = {
      includes = with den.aspects; [
        portable-dotfiles
      ];
      homeManager = {
        imports = [
          ./_dotfiles.nix
        ];
      };
    };
  };
}
