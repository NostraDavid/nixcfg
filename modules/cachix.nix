{...}: {
  # Pull from commonly used Cachix binary cache to reduce local builds.
  nix.settings = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://numtide.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
    ];

    # Caching and build optimizations
    connect-timeout = 5; # Don't hang forever if a cache is down
    fallback = true; # Fall back to building from source if a binary cache fails
    keep-outputs = true; # Keep build-time dependencies to speed up future rebuilds
    keep-derivations = true;
    auto-optimise-store = true; # Hardlink identical files in the store to save space
  };
}
