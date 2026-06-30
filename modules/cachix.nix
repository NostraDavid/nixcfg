_: {
  # Pull from commonly used Cachix binary cache to reduce local builds.
  nix.settings = {
    extra-substituters = [
      "https://thaumatorium.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://devenv.cachix.org"
      "https://nix-community.cachix.org"
      "https://numtide.cachix.org"
      "https://cache.nixos.org"
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
