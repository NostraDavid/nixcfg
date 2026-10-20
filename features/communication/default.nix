_: {
  den.aspects = {
    communication = {
      homeManager = {
        imports = [
          ./_home.nix
        ];
      };
    };
    work-communication = {
      homeManager = {
        imports = [
          ./_work.nix
        ];
      };
    };
  };
}
