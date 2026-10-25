{den, ...}: {
  den.aspects = {
    workstation-extra = {
      includes = with den.aspects; [
        cloud
        code-navigation
      ];
      homeManager = {
        imports = [
          ./_default.nix
        ];
      };
    };
    mediaTools = {
      homeManager = {
        imports = [
          ./_media-tools.nix
        ];
      };
    };
  };
}
