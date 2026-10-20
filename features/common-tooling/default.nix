_: {
  den.aspects.common-tooling = {
    homeManager = {unstable, ...}: {
      home.packages = with unstable; [
        actionlint
        hurl
        lnav
        nix-index
        nix-tree
        nvd
        sqruff
        watchexec
      ];
    };
  };
}
