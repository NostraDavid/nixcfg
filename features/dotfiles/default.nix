{den, ...}: {
  den.aspects = {
    worktrunk = {
      homeManager = {
        imports = [
          ./_worktrunk.nix
        ];
      };
    };
    agent-skills = {
      homeManager.imports = [
        ./_agent-skills.nix
      ];
    };
    portable-dotfiles = {
      includes = with den.aspects; [
        agent-skills
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
