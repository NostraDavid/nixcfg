_: {
  # Pull from commonly used Cachix binary cache to reduce local builds.
  nix.settings = {
    trusted-users = [
      "root"
      "david"
    ];
    # https://bmcgee.ie/posts/2023/12/til-how-to-optimise-substitutions-in-nix/
    extra-substituters = [
      "https://thaumatorium.cachix.org?priority=1"
      "https://cuda-maintainers.cachix.org?priority=2"
      "https://devenv.cachix.org?priority=3"
      "https://nix-community.cachix.org?priority=4"
      "https://numtide.cachix.org?priority=5"
      "https://cache.nixos.org?priority=6"
    ];
    extra-trusted-public-keys = [
      "thaumatorium.cachix.org-1:KbOXBN34Tv0AeoRRhvBKoZHUfgmOALmfyQWeRE6MITo="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];

    # Caching and build optimizations
    connect-timeout = 5; # Don't hang forever if a cache is down
    fallback = true; # Fall back to building from source if a binary cache fails
    keep-outputs = true; # Keep build-time dependencies to speed up future rebuilds
    keep-derivations = true;
    auto-optimise-store = true; # Hardlink identical files in the store to save space
  };
}
