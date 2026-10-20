_: {
  den.aspects.annotation = {
    darwin.homebrew.casks = [
      "ksnip"
    ];
    homeManager = {
      lib,
      pkgs,
      unstable,
      ...
    }: {
      home.packages =
        lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          unstable.ksnip
        ]
        ++ [
          unstable.pinta
        ];
    };
  };
}
