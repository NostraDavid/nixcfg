_: {
  den.aspects.common-tooling = {
    homeManager = {
      stable,
      local,
      unstable,
      ...
    }: {
      home.packages = with unstable; [
        actionlint
        hurl
        lnav
        nix-index
        nix-tree
        nvd
        sqruff
        watchexec
        local.espeak-ng
        (stable.piper-tts.override {
          withAlignment = false;
          withHTTP = false;
          withTrain = false;
        })
      ];
    };
  };
}
